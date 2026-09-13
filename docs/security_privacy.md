# GlobMint — Vault Privacy: Security Review

*Companion to README §7 (Security). Target: teams auditing the commitment-based
privacy mode (`GLOBMINT_PRIVACY_MODE=true`) before mainnet.*

## 1. What privacy mode does and does not promise

Privacy mode replaces **raw-address balance storage and raw-address events** with
**commitment-based storage and commitment-only events**:

| Aspect | Privacy mode OFF (legacy) | Privacy mode ON |
|---|---|---|
| Balance storage | `_balances[user]` (raw address) + `_privateBalances[hash(user, 0)]` | `_privateBalances[keccak256(user, salt)]` only |
| Deposit entry point | `deposit(amount)` (raw address) | `depositFor(user, salt, amount)` |
| Withdrawal entry point | `withdraw(amount)` (raw address) | `withdrawWithSalt(salt, amount)` |
| Deposit event | `Deposited(commitment, user, amount)` + `DepositedRaw(user, amount)` | `DepositedPrivate(commitment, amount)` |
| Withdrawal event | `Withdrawn(commitment, user, amount)` + `WithdrawnRaw(user, amount)` | `WithdrawnPrivate(commitment, amount)` |
| `balanceOf(addr)` | real balance | always `0` for everyone |
| `balanceOfCommitment(hash)` | — | real balance for the commitment holder |

**What it guarantees:** an external observer reading public chain data cannot
link a raw wallet address to a vault balance, and cannot query "how much does
address X hold".

**What it does NOT guarantee:**
- *Deposit-value privacy.* `DepositedPrivate` events still disclose the amount.
  Anyone can see "10 USDC was committed to some commitment hash".
- *Anonymity from correlated analysis.* If the user's wallet is already known
  on-chain (e.g. they withdrew from it, or sent to an exchange), cluster
  analysis can still link deposits. Privacy mode "hides in plain sight", it is
  not mixers/Tornado-style anonymity.
- *Backend transparency.* The backend stores the salt. An insider who reads
  `user_salts` can reconstruct commitments. The trust boundary is "backend
  operator is honest."

## 2. Where the RAW ADDRESS legitimately still appears (leak inventory)

Every place an address must appear, with why it is unavoidable and what we do:

| # | Surface | Why it appears | Mitigation |
|---|---|---|---|
| 1 | The user's **deposit-initiation transaction** to the USDC `approve(usdc, vault, amount)` call | USDC approval is signed by the user's wallet; `tx.from` is public | Static, time-invariant; does not reveal balances |
| 2 | The **relay/`depositFor` transaction** from the backend signer | The vault pulls USDC from the signer; `tx.from` = backend signer's wallet | Backend signer should be a dedicated address with no identity link |
| 3 | The **USDC `Transfer` event** into the vault (topic `to` = vault) | ERC-20 Transfer is emitted by USDC itself, not by the vault | In privacy mode the indexer ignores raw transfers to the vault; only `DepositedPrivate` drives crediting |
| 4 | The **withdrawal transaction + outbound USDC `Transfer`** to the user | Withdrawals send USDC back to `msg.sender`; both the tx and the ERC-20 Transfer carry the address | Event on the vault carries only the commitment; see §2.1 residual risk |
| 5 | **`getDepositInfo` reveals the user's deposit *address*** | The savings flow needs the user's on-chain address to derive the salt-based commitment API | The deposit address is the user's public wallet; balances remain hidden |
| 6 | **Backend `IndexerEvent` rows** (`From = commitment`) | Audit log for replay/idempotency | Stores the commitment hash, never the raw address; `deposit_addresses.address` is still present by design (users opt in by linking) |

### 2.1 Residual risk: withdrawal links deposit ↔ address

`withdrawWithSalt` must send USDC *somewhere* the user controls — the user's own
address. The transaction itself (and the USDC `Transfer`) exposes that address
in meta-data. → An observer can say "the commitment that holds a balance paid
out to address A", which links A to the commitment's *exists-and-was-funded*
fact (not necessarily its exact balance, since partial withdrawals obscure the
exact amount).

**Accepted.** A fully anonymous withdrawal needs a ZK proof (see §4 roadmap).
Current design minimizes the leak: the *deposit side* never links address to
balance, and partial withdrawals obscure running totals.

## 3. Indexer security properties

- **Resolution requires both tables:** the indexer builds
  `keccak256(address, salt) → userID` by joining `deposit_addresses` and
  `user_salts` (`UserSaltsRepository.ListLinks`). Without the *salted* row an
  outside observer cannot brute-force the map (128-bit salts).
- **Unlinked commitments are dropped, never fallback-credited.** In privacy mode
  the `GLOBMINT_VAULT_FALLBACK_USER_ID` demo fallback is deliberately *not* used
  for commitment events — a commitment we cannot resolve could belong to any
  user, and crediting the fallback would mis-credit money.
- **Idempotency is per `(tx_hash, log_index)`** with the `vault-deposit-vault-`
  prefix, distinct from the legacy transfer path, so the two paths never
  double-credit the same deposit and replays are deduped.
- **Salts are preserved on re-link** (`SetDepositAddress`); on-chain commitments
  created before a re-link keep resolving to the same user.

## 4. Threat model (privacy mode)

| Attacker | Who they are | What they learn | What they cannot learn |
|---|---|---|---|
| Block-explorer observer | Anyone reading public chain data | That some deposit of amount X happened to the vault; the vault's total deposits | Which address owns it; `balanceOf(addr)` (always 0); the user's balance from raw lookups |
| Exchange/correlation analyst | Observes the user's known wallet | If the user *withdraws*, the same address is linked to its *own* committed funds | The committed running balance pre/post partial withdrawals (only exists-not-exists + outflow) |
| Malicious relayer hitting `depositFor(alice, wrongSalt)` | Anyone writing txs | That `keccak256(alice, attemptedSalt)` has 0 balance | Nothing — the commitment is checked on-chain and wrong salts have no balance |
| Backend insider | Operator with DB read | Raw addresses (`deposit_addresses`) and salts (`user_salts`) → can recompute commitments | Cannot move user USDC: vault is non-custodial, no owner/admin |
| Contract-level static analyst | Anyone reading bytecode | Storage layout uses `keccak256` keys for balances | The preimage `(address, salt)` — 128-bit salt |
| Brute-forcer | High compute | A commitment *that holds funds* (given the address or salt alone, impossible to guess) | Committing preimage: needs both halves; guessing requires winning a 128-bit oracle test per attempt |

## 5. Configuration, limits and gaps

- `GLOBMINT_PRIVACY_MODE` must be set **before** the first deposits. Toggling
  later is safe (mappings coexist) but the *transition window* (raw-address
  `balanceOf` populated from legacy-era deposits) is visible. For a fresh
  privacy launch, deploy the vault with `initialPrivacy = true`.
- `deposit_addresses.salt` (migration `0013`) is a **reference copy**; the
  authority is `user_salts.salt`. Never persist a plaintext salt to logs.
- The salt is **16 bytes (`128 bits`)**. If the environment is ever shared or
  its generator weakened (e.g. `math/rand` instead of `crypto/rand`), rotate
  all salts *and* their associated on-chain commitments — see §6.

## 6. Incident response: salt rotation

A leaked or suspected-compromised salt set means every commitment it governs is
now guessable by an insider with the linked address. Procedure:

1. Pause the indexer (`GLOBMINT_PRIVACY_MODE=false` restart is **not** the
   fix — do not lose crediting; instead stop accepting *new* deposits by
   pausing the vault or pointing the UI at a pause notice).
2. Regenerate salts (`user_salts`), re-compute commitments.
3. Have users re-deposit or migrate balances on-chain into the new commitment
   (vault supports migrating from legacy → commitment, not commitment-A →
   commitment-B, so a *funds-out / deposit-for* round trip may be required).
4. Rotate the backend signer address before re-opening deposits.

## 7. Roadmap (accepted mitigations for §2.1)

- **ZK withdrawal proof:** a zero-knowledge circuit that proves
  `keccak256(user, salt)` and a correct balance ownership *without revealing
  `user`*; funds are sent to a fresh derived address. This removes the
  withdrawal link without changing the balance model.
- **Stealth / nullifier commitments** to hide the commitment itself.
- **Account abstraction wallets** so the user's EOA is never `tx.from` for
  vault interactions.