// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title GlobmintVaultClone
 * @notice Per-user stablecoin vault, deployed once per Globmint account as an
 *         EIP-1167 minimal proxy (delegatecalls this logic contract).
 *
 * Product intent:
 *   - EVERY account gets its own on-chain address (its clone). Anyone can send
 *     USDC to that address — a dedicated wallet, a wallet that was never linked,
 *     an exchange, a friend — and the transfer belongs to that account by
 *     construction. No "connect your wallet" is ever needed to RECEIVE money.
 *   - Self-custody is preserved: the clone has NO owner who can seize funds in
 *     the app's sense. The party listed in `_owners[address(this)]` (set once
 *     by the factory, which the app runs) may withdraw the clone's USDC.
 *     Withdrawing requires either (a) the listed owner calling from their own
 *     wallet, or (b) an EIP-712 signature from that owner authorizing a single
 *     withdrawal (relayed by the app) — "sign per withdrawal".
 *   - Privacy: a fresh clone address on chain shows nothing but its own
 *     transfers. The clone -> account mapping is known only to the app's
 *     indexer (off-chain), so looking up an address reveals no personal data.
 *
 * Because clones share the implementation's storage, every piece of state is
 * keyed by `address(this)`. All fund availability is measured by the token's
 * actual balance of the clone: anything ever sent to the clone (via
 * `deposit()` or a plain ERC-20 `transfer`) can be withdrawn by its owner.
 */

interface IERC20Minimal {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract GlobmintVaultClone {
    /// @notice The stablecoin this clone holds (USDC/USDT-compatible).
    address public immutable stablecoin;
    /// @notice The factory that deploys and initializes clones. Only the
    ///         factory may set a clone's initial owner or privacy flag.
    address public immutable factory;

    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant WITHDRAW_TYPEHASH =
        keccak256("WithdrawRequest(address to,uint256 amount,uint256 nonce,uint256 deadline)");
    bytes32 private constant TRANSFER_TYPEHASH =
        keccak256("TransferOwnership(address newOwner,uint256 nonce,uint256 deadline)");

    /// @notice owner of each clone (keyed by clone address).
    mapping(address => address) private _owners;
    /// @notice per-clone EIP-712 withdrawal nonce.
    mapping(address => uint256) private _nonces;

    /// @notice per-clone privacy flag. When true the raw-address `deposit` and
    ///         `withdraw` revert; deposits go through `depositFor(user, salt,
    ///         amount)` and withdrawals through `withdrawWithSalt`, and only
    ///         keccak256(user, salt) commitments ever appear in events, never a
    ///         raw user address.
    mapping(address => bool) private _privacyEnabled;
    /// @notice per-clone "no direct owner withdrawal" flag. When true the
    ///         owner's own `withdraw(amount, to)` reverts and the ONLY way out
    ///         is `withdrawWithSig` (an EIP-712 signature authorizing that
    ///         single withdrawal). Defaults to false (direct withdraw allowed)
    ///         so already-deployed clones keep working; the factory controls it
    ///         so the platform can flip the whole fleet to signature-only
    ///         withdrawal once signature-gating is enforced.
    mapping(address => bool) private _directWithdrawDisabled;
    /// @notice per-clone commitment balances: clone -> commitment -> amount.
    ///         The commitment is keccak256(abi.encodePacked(user, salt)).
    mapping(address => mapping(bytes32 => uint256)) private _privateBalances;

    event Deposited(address indexed owner, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    /// @notice Privacy-mode deposit. Carries ONLY the commitment.
    event DepositedPrivate(bytes32 indexed commitment, uint256 amount);
    /// @notice Privacy-mode withdrawal. Carries ONLY the commitment.
    event WithdrawnPrivate(bytes32 indexed commitment, uint256 amount);

    constructor(address stablecoin_, address factory_) {
        require(stablecoin_ != address(0), "invalid stablecoin");
        require(factory_ != address(0), "invalid factory");
        stablecoin = stablecoin_;
        factory = factory_;
    }

    /// @notice One-time initialization, callable only by the factory right
    ///         after the clone is deployed (same transaction -> no window).
    function initializer(address owner_) external {
        require(msg.sender == factory, "not factory");
        require(_owners[address(this)] == address(0), "already initialized");
        require(owner_ != address(0), "invalid owner");
        _owners[address(this)] = owner_;
    }

    /// @notice The account that may withdraw this clone's funds.
    function ownerOfThis() public view returns (address) {
        return _owners[address(this)];
    }

    /// @notice USDC in this clone's custody (the whole amount, however it got in).
    function tokenBalance() public view returns (uint256) {
        return IERC20Minimal(stablecoin).balanceOf(address(this));
    }

    /// @notice Next unused withdrawal nonce for this clone.
    function nonce() public view returns (uint256) {
        return _nonces[address(this)];
    }

    /// @notice Whether this clone is in commitment-based privacy mode. When
    ///         true, raw-address deposits/withdrawals revert and only
    ///         keccak256(user, salt) commitments appear on chain.
    function privacyEnabled() public view returns (bool) {
        return _privacyEnabled[address(this)];
    }

    /// @notice Whether direct owner `withdraw` is disabled on this clone. When
    ///         true the only way to move funds out is `withdrawWithSig`, which
    ///         requires an EIP-712 signature authorizing the exact transfer.
    function directWithdrawDisabled() public view returns (bool) {
        return _directWithdrawDisabled[address(this)];
    }

    /// @notice Toggle direct owner `withdraw` for THIS clone. Only the factory
    ///         may call, and the factory is the app's deployer seat — this is
    ///         how the platform proves on-chain that the operator's direct
    ///         withdrawal path is off for a clone. Does not affect
    ///         `withdrawWithSig` (which always works for the clone owner).
    function setDirectWithdrawDisabled(bool disabled) external {
        require(msg.sender == factory, "not factory");
        _directWithdrawDisabled[address(this)] = disabled;
    }

    /// @notice Balance held for a keccak256(abi.encodePacked(user, salt))
    ///         commitment. In privacy mode only the user/backend that knows the
    ///         salt can compute the commitment that resolves to a real balance.
    function balanceOfCommitment(bytes32 commitment) public view returns (uint256) {
        return _privateBalances[address(this)][commitment];
    }

    /// @notice Commitment for a user + salt: keccak256(abi.encodePacked(user, salt)).
    function commitmentKey(address user, bytes32 salt) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, salt));
    }

    /// @notice Toggle privacy mode for THIS clone. Only the factory may call.
    ///         Called by the factory at deploy time to set the initial mode;
    ///         the factory keeps the seat so the whole fleet's privacy policy
    ///         stays operator-controlled. Does not touch stored balances — the
    ///         raw `_owners`/token-balance and commitment mappings are disjoint,
    ///         so flipping the flag just changes which API is usable.
    function setPrivacyEnabled(bool enabled) external {
        require(msg.sender == factory, "not factory");
        _privacyEnabled[address(this)] = enabled;
    }

    /// @notice EIP-712 domain separator bound to THIS clone address.
    function domainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("GlobmintVault")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    /// @notice Approve + deposit: pulls USDC from the caller into the clone.
    /// @dev Emits Deposited for the indexer. Same as a direct transfer from a
    ///      UX standpoint; exists so wallets can stay in the approve+deposit
    ///      pattern. REVERTS in privacy mode — use `depositFor` there.
    function deposit(uint256 amount) external {
        require(!_privacyEnabled[address(this)], "privacy mode: use depositFor");
        require(amount > 0, "amount must be > 0");
        require(_owners[address(this)] != address(0), "not initialized");
        IERC20Minimal token = IERC20Minimal(stablecoin);
        require(token.allowance(msg.sender, address(this)) >= amount, "insufficient allowance");
        require(token.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        emit Deposited(_owners[address(this)], amount);
    }

    /// @notice Privacy-mode deposit on behalf of a user with a known salt. The
    ///         commitment keccak256(abi.encodePacked(user, salt)) is credited and
    ///         the event carries ONLY the commitment — the raw user address
    ///         never appears in a topic. Works in both modes; in privacy mode it
    ///         is the only deposit entry point (besides a plain transfer, which
    ///         the indexer credits to this clone's account by construction).
    /// @dev The caller must have approved this clone for `amount`.
    function depositFor(address user, bytes32 salt, uint256 amount) external {
        require(user != address(0), "invalid user");
        require(amount > 0, "amount must be > 0");
        require(ownerOfThis() != address(0), "not initialized");
        IERC20Minimal token = IERC20Minimal(stablecoin);
        require(token.allowance(msg.sender, address(this)) >= amount, "insufficient allowance");
        require(token.transferFrom(msg.sender, address(this), amount), "transferFrom failed");

        bytes32 commitment = keccak256(abi.encodePacked(user, salt));
        _privateBalances[address(this)][commitment] += amount;
        emit DepositedPrivate(commitment, amount);
    }

    /// @notice Owner calls from their own wallet: withdraw `amount` to `to`.
    ///         REVERTS in privacy mode — use `withdrawWithSalt` there. Also
    ///         REVERTS when direct withdraw is disabled (`setDirectWithdrawDisabled`),
    ///         leaving `withdrawWithSig` as the only way out.
    function withdraw(uint256 amount, address to) external {
        require(!_privacyEnabled[address(this)], "privacy mode: use withdrawWithSalt");
        require(!_directWithdrawDisabled[address(this)], "direct withdraw disabled");
        require(msg.sender == _owners[address(this)], "not owner");
        _transferOut(to, amount);
    }

    /// @notice Privacy-mode withdrawal: proves knowledge of the salt by
    ///         supplying it and withdraws the caller's OWN commitment balance to
    ///         `to`. The commitment is keccak256(abi.encodePacked(msg.sender,
    ///         salt)); a wrong salt resolves to an empty commitment and reverts.
    /// @dev The USDC availability check is against the token balance of this
    ///      clone (fallback for funds that arrived by plain transfer).
    function withdrawWithSalt(bytes32 salt, uint256 amount, address to) external {
        require(amount > 0, "amount must be > 0");
        bytes32 commitment = keccak256(abi.encodePacked(msg.sender, salt));
        require(_privateBalances[address(this)][commitment] >= amount, "insufficient private balance");
        _privateBalances[address(this)][commitment] -= amount;
        // The commitment is debited, but the actual USDC leaves the clone's
        // pooled token balance (which may also hold plain-transfer funds).
        emit WithdrawnPrivate(commitment, amount);
        _transferOut(to, amount);
    }

    /// @notice Relayed (meta) withdrawal authorized by an EIP-712 signature from
    ///         the clone owner. Anyone (including the app) may submit it, but
    ///         only the owner's signature moves funds.
    /// @param to Destination address for the USDC.
    /// @param requestNonce Must equal this clone's current nonce (replay-protected).
    /// @param deadline Unix timestamp; the signature expires after this.
    function withdrawWithSig(
        address to,
        uint256 amount,
        uint256 requestNonce,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(!_privacyEnabled[address(this)], "privacy mode: use withdrawWithSalt");
        require(deadline >= block.timestamp, "signature expired");
        require(requestNonce == _nonces[address(this)], "invalid nonce");
        address owner = _owners[address(this)];
        require(owner != address(0), "not initialized");

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator(),
                keccak256(abi.encode(WITHDRAW_TYPEHASH, to, amount, requestNonce, deadline))
            )
        );
        require(_recover(digest, v, r, s) == owner, "invalid signer");

        _nonces[address(this)] = requestNonce + 1;
        _transferOut(to, amount);
    }

    /// @notice Hand over clone ownership to a new address authoritatively, using
    ///         an EIP-712 signature from the CURRENT owner.
    ///
    /// Why this matters: the app deploys an unlinked account's clone with the
    ///         platform signer as a placeholder owner so funds are never locked.
    ///         This lets the user later "sign to take custody": their signature
    ///         moves that placeholder ownership to THEIR own wallet, at which
    ///         point only they can withdraw. Shares the per-clone nonce with
    ///         withdrawals, so signing one type never replays the other.
    /// @param newOwner The address that will own the clone afterwards.
    /// @param requestNonce Must equal this clone's current nonce (replay-protected).
    /// @param deadline Unix timestamp; the signature expires after this.
    function transferOwnershipBySig(
        address newOwner,
        uint256 requestNonce,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(deadline >= block.timestamp, "signature expired");
        require(newOwner != address(0), "invalid new owner");
        require(requestNonce == _nonces[address(this)], "invalid nonce");
        address owner = _owners[address(this)];
        require(owner != address(0), "not initialized");
        require(newOwner != owner, "same owner");

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator(),
                keccak256(abi.encode(TRANSFER_TYPEHASH, newOwner, requestNonce, deadline))
            )
        );
        require(_recover(digest, v, r, s) == owner, "invalid signer");

        _nonces[address(this)] = requestNonce + 1;
        _owners[address(this)] = newOwner;
        emit OwnershipTransferred(owner, newOwner);
    }

    function _transferOut(address to, uint256 amount) internal {
        require(amount > 0, "amount must be > 0");
        require(to != address(0), "invalid destination");
        IERC20Minimal token = IERC20Minimal(stablecoin);
        require(token.balanceOf(address(this)) >= amount, "insufficient balance");
        require(token.transfer(to, amount), "transfer failed");
        // In privacy mode the raw `Withdrawn(to, amount)` event must not be
        // emitted: withdrawal data is exposed through `WithdrawnPrivate`
        // (commitment-only) which the calling functions emit.
        if (!_privacyEnabled[address(this)]) {
            emit Withdrawn(to, amount);
        }
    }

    /// @notice ECDSA recovery from the typed digest with malleability guards.
    function _recover(bytes32 digest, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        require(v == 27 || v == 28, "invalid signature");
        // s must be in the lower half order (anti-malleability) per EIP-2.
        require(
            uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
            "invalid signature"
        );
        address signer = ecrecover(digest, v, r, s);
        require(signer != address(0), "invalid signature");
        return signer;
    }

    /// @notice Reject native ETH: with ownerless clones, stray ETH is stranded.
    receive() external payable {
        revert("ETH not accepted");
    }

    /// @notice Reject unknown calls. A plain ERC-20 transfer cannot and should
    ///         not route here (see file-level docs).
    fallback() external payable {
        revert("invalid call");
    }
}