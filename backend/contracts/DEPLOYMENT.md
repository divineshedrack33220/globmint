# GlobmintVault — Deployment & Backend Integration

`GlobmintVault` is the non-custodial on-chain savings contract. Each user has
their own balance tracked on-chain (`balanceOf[user]`), and **no one** — not even
an operator — can seize, transfer, or burn another user's funds. Deposits and
withdrawals are initiated by the user's own wallet.

The backend never holds user private keys. Its role is to:

1. Record which on-chain wallet address belongs to which user (a "deposit
   address"), so the app can show a user their own address and the vault
   details needed to deposit.
2. Expose those details so a client wallet can build the `approve` + `deposit`
   transactions.

---

## 1. The contract interface

Source: `backend/contracts/contracts/GlobmintVault.sol`
(Solidity `^0.8.24`, no OpenZeppelin dependency.)

### State / reads

| Signature | Returns | Meaning |
|---|---|---|
| `stablecoin()` | `address` | The ERC-20 stablecoin held (e.g. USDC). |
| `balanceOf(address user)` | `uint256` | USDC (base units) credited to `user`. |
| `totalDeposits()` | `uint256` | Total USDC held across all users. |
| `tokenDecimals()` | `uint8` | Stablecoin decimals (6 for USDC). |

### Writes (all user-initiated)

| Signature | Meaning |
|---|---|
| `deposit(uint256 amount)` | Pull `amount` USDC from `msg.sender` and credit `balanceOf[msg.sender]`. Requires the user to have `approve`d the vault first. |
| `depositFor(address user, uint256 amount)` | Same, but credits `user` while `msg.sender` pays. Convenient for a deposit-address flow. |
| `depositWithPermit(address user, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)` | Single-step deposit using an EIP-2612 `permit` signature (no separate `approve`). Reverts if the token lacks `permit`. |
| `withdraw(uint256 amount)` | Send `amount` USDC **only to `msg.sender`**. No third-party withdrawal is possible. |

### Events

- `Deposited(address indexed user, uint256 amount)`
- `Withdrawn(address indexed user, uint256 amount)`

### Notes for integration

- Amounts are in **base units** (6 decimals for USDC): to deposit `1.00` USDC,
  pass `1000000`.
- The vault is keyed by **address**, not email. A user's on-chain balance is
  `balanceOf[their_wallet_address]`. The backend maps users to wallet addresses
  (see the deposit-address flow below), but the on-chain source of truth is the
  address itself.

---

## 2. Local test

```bash
cd backend/contracts
npx hardhat test        # 9 tests: deposit, depositFor, withdraw,
                        # over-withdrawal revert, no-admin isolation, totalDeposits
npx hardhat compile
```

---

## 3. Deploying to Sepolia

Prerequisites:
- Node 20+, a funded deployer key, and an Alchemy (or other) Sepolia RPC URL.

Env vars (also in the repo `.env`, gitignored):

```bash
GLOBMINT_BLOCKCHAIN_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/...
GLOBMINT_DEPLOYER_PRIVATE_KEY=...            # 0x-prefixed, testnet only
```

Deploy:

```bash
cd backend/contracts
npx hardhat run scripts/deploy.js --network sepolia
```

`scripts/deploy.js` deploys `GlobmintVault` bound to the canonical Sepolia USDC
(`0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`) and writes the address to
`deployments/address.json` (gitignored):

```json
{ "vault": "0x...", "stablecoin": "0x1c7D...", "network": "sepolia" }
```

Then point the backend at it (backend/.env):

```bash
GLOBMINT_VAULT_CONTRACT_ADDRESS=0x...        # the deployed vault address
GLOBMINT_STABLECOIN_CONTRACT_ADDRESS=0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
GLOBMINT_BLOCKCHAIN_MODE=real                # mock = no real chain calls
```

> For mainnet, change the stablecoin in `deploy.js` to
> `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB4`.

---

## 4. Backend integration (deposit-address flow)

### Endpoints (all auth-protected)

**`GET /api/v1/savings/deposit-info`**

Returns the user's linked on-chain address (empty until set) plus everything a
client wallet needs to build a vault deposit:

```json
{
  "address": "0x...",
  "vault_contract": "0x...",
  "stablecoin_symbol": "USDC",
  "stablecoin_name": "USD Coin",
  "stablecoin_decimals": 6,
  "stablecoin_contract": "0x1c7D...",
  "network": "sepolia",
  "chain_id": 11155111,
  "mode": "mock"
}
```

**`PUT /api/v1/savings/deposit-address`** with body `{ "address": "0x..." }`

Links (or re-links) the user's own wallet address. Rejects:
- malformed addresses (`400 INVALID_REQUEST`),
- an address already claimed by another user (`409 CONFLICT`).

### Client deposit sequence (non-custodial)

1. `PUT /savings/deposit-address` with the user's wallet address.
2. `GET /savings/deposit-info` to read `vault_contract` + `stablecoin_contract`
   + `stablecoin_decimals`.
3. In the user's wallet, call, on the stablecoin:
   `approve(vault_contract, amount)`; then on the vault:
   `deposit(amount)` (or `depositFor(user, amount)` / `depositWithPermit(...)`).
4. Optionally verify with `balanceOf(user)` (read-only) via an RPC.

The user signs these transactions themselves; the backend never sees or holds
their key, preserving the "nobody controls your money" guarantee.

### How the deposit-address is stored

`deposit_addresses` table (migration `0004_deposit_address.sql`):

| column | notes |
|---|---|
| `user_id` (PK) | Globmint user, one deposit address each |
| `address` (unique) | the user's on-chain wallet address |

A deposit address cannot be claimed by more than one user, and each user has at
most one. `DepositAddressRepository` (`backend/internal/storage/postgres/
deposit_address_repo.go`) provides `FindByUser`, `Set` (upsert) and `OwnerOf`.
`SavingsService` (`backend/internal/services/savings.go`) encapsulates the
business rules; config comes from `GLOBMINT_*` env vars via `services.FromConfig`.

---

## 5. Security model (why funds can't be seized)

- `GlobmintVault` has **no `owner`/`admin`** and no function that moves another
  user's funds. `withdraw` only ever sends to `msg.sender`.
- Balances are per-user and isolated; the contract math uses `SafeMath` and the
  CEI pattern (checks-effects-interactions) to guard against reentrancy.
- The backend holds no user private keys and no operator account can pull funds
  from the vault. Users transact directly with the contract from their own
  wallets.
