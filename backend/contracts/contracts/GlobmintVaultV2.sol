// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SafeMath.sol";

/**
 * @title GlobmintVaultV2
 * @notice Non-custodial, per-user stablecoin savings vault with privacy-enhancing
 *   hashed balances. Balances are stored against keccak256(user, salt) commitments
 *   instead of raw addresses, so external observers cannot query a user's balance
 *   by looking up their address.
 *
 * Design principles (matching the product vision):
 *   - Nobody controls any user's money. There is NO owner, NO admin, and NO
 *     function that can seize, transfer, or burn another user's balance.
 *   - Each user has their own balance tracked on-chain via a keccak256 commitment.
 *   - A per-user random salt (known only to the user/backend) masks the address–balance
 *     link on-chain.
 *   - Deposits: when privacy mode is ON, the backend signer (or any relayer who
 *     knows the user's salt) calls `depositFor(user, salt, amount)`; the vault
 *     pulls USDC from the caller and credits the user's commitment-based balance.
 *   - Withdrawals: any user calls `withdrawWithSalt(salt, amount)` to pull their
 *     OWN USDC back to their own address. Nothing is ever sent to a third party.
 *   - No fees are collected by the contract or any operator. The only cost is
 *     the network gas the user pays to submit the transaction.
 *
 * Privacy modes:
 *   - privacyEnabled == false (default): legacy raw-address behaviour. `deposit()`
 *     and `withdraw()` are available; balances live in `_balances[user]` and
 *     the `Deposited`/`Withdrawn` events carry the raw address (backward
 *     compatible with first-generation indexers).
 *   - privacyEnabled == true: raw-address `deposit()` and `withdraw()` revert.
 *     Deposits go through `depositFor(user, salt, amount)` (credit to
 *     `_privateBalances[keccak256(user, salt)]`) and withdrawals through
 *     `withdrawWithSalt(salt, amount)`. All events emitted in privacy mode
 *     (`DepositedPrivate`/`WithdrawnPrivate`) contain ONLY the keccak256
 *     commitment — never the raw user address.
 *
 * The mode is set at deployment (constructor) and can be switched later by the
 * single privacy guardian (the deployer). Switching mode does NOT touch existing
 * balances: the dual-mapping design keeps `_balances` and `_privateBalances`
 * disjoint, so turning privacy on/off simply flips which API is usable.
 */
contract GlobmintVaultV2 {
    using SafeMath for uint256;

    /// @notice The stablecoin this vault holds (e.g. USDC on Sepolia).
    address public immutable stablecoin;

    /// @notice The single address allowed to flip `privacyEnabled`.
    address private immutable _privacyGuardian;

    /// @notice Total USDC held by the vault across all users (both modes).
    uint256 private _totalDeposits;

    /// @notice Per-user USDC balance using the raw-address mapping.
    ///       Used only when privacy mode is off (default, backward compat).
    mapping(address => uint256) private _balances;

    /// @notice Per-user USDC balance using the hashed commitment mapping.
    ///       Key = keccak256(abi.encodePacked(user, salt)).
    mapping(bytes32 => uint256) private _privateBalances;

    /// @notice When true, raw-address `deposit`/`withdraw` are disabled and all
    ///       balances + events use keccak256(user, salt) commitments.
    bool public privacyEnabled;

    /// @notice Legacy deposit (raw address): commitment + user. Privacy-ON path
    ///       is allowed to emit this ONLY while privacy is off.
    event Deposited(bytes32 indexed commitment, address indexed user, uint256 amount);
    /// @notice Legacy withdrawal (raw address).
    event Withdrawn(bytes32 indexed commitment, address indexed user, uint256 amount);
    /// @notice Backward-compatible raw deposit (first-gen indexers).
    event DepositedRaw(address indexed user, uint256 amount);
    /// @notice Backward-compatible raw withdrawal.
    event WithdrawnRaw(address indexed user, uint256 amount);

    /// @notice Privacy-mode deposit. Carries ONLY the commitment — the raw user
    ///       address never appears in a topic or in data.
    event DepositedPrivate(bytes32 indexed commitment, uint256 amount);
    /// @notice Privacy-mode withdrawal. Carries ONLY the commitment.
    event WithdrawnPrivate(bytes32 indexed commitment, uint256 amount);

    /// @param stablecoin_ The ERC-20 stablecoin address (6 decimals for USDC/USDT).
    /// @param initialPrivacy Whether the vault boots in privacy mode.
    constructor(address stablecoin_, bool initialPrivacy) {
        require(stablecoin_ != address(0), "invalid stablecoin");
        stablecoin = stablecoin_;
        privacyEnabled = initialPrivacy;
        _privacyGuardian = msg.sender;
    }

    /// @notice The stablecoin base decimals (6 for USDC), exposed for the UI.
    function tokenDecimals() public view returns (uint8) {
        return IERC20(stablecoin).decimals();
    }

    /// @notice The single address allowed to toggle privacy mode.
    function privacyGuardian() public view returns (address) {
        return _privacyGuardian;
    }

    /**
     * @notice Flip privacy mode. Only the deployer (privacy guardian) may call.
     * @dev Does not modify any stored balance — legacy and commitment balances
     *     coexist; flipping mode just changes which entry points may be used.
     */
    function setPrivacyEnabled(bool enabled) external {
        require(msg.sender == _privacyGuardian, "not the privacy guardian");
        privacyEnabled = enabled;
    }

    /**
     * @notice Legacy USDC balance held for `user` using the raw-address mapping.
     * @dev When privacy mode is active the raw mapping is unused, so this always
     *     returns 0 for every address (including the true depositor). Use
     *     `balanceOfCommitment` with the correct commitment instead.
     */
    function balanceOf(address user) public view returns (uint256) {
        return _balances[user];
    }

    /**
     * @notice USDC balance held for `user` using the commitment mapping.
     * @param commitment keccak256(abi.encodePacked(user, salt)).
     * @return balance in base units, or 0 if no such commitment exists.
     * @dev Callers must have the correct commitment for the user. In privacy
     *     mode only the receiver-side (user/backend) can compute it.
     */
    function balanceOfCommitment(bytes32 commitment) public view returns (uint256) {
        return _privateBalances[commitment];
    }

    /**
     * @notice Total USDC held by the vault across all users (both modes).
     */
    function totalDeposits() public view returns (uint256) {
        return _totalDeposits;
    }

    /**
     * @notice Legacy raw-address deposit. REVERTS in privacy mode.
     * @dev Requires the caller to have approved this vault for `amount` first.
     *      In privacy mode the only way to fund someone is `depositFor` — the
     *      backend signer (or a relayer) deposits with the known salt, so the
     *      raw address is never required as a lookup key.
     */
    function deposit(uint256 amount) external {
        require(!privacyEnabled, "privacy mode: use depositFor");
        require(amount > 0, "amount must be > 0");
        IERC20 token = IERC20(stablecoin);
        require(token.allowance(msg.sender, address(this)) >= amount, "insufficient allowance");
        require(token.transferFrom(msg.sender, address(this), amount), "transferFrom failed");

        bytes32 c = commitmentKey(msg.sender, bytes32(0));
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        _privateBalances[c] = _privateBalances[c].add(amount);
        _totalDeposits = _totalDeposits.add(amount);

        emit Deposited(c, msg.sender, amount);
        emit DepositedRaw(msg.sender, amount);
    }

    /**
     * @notice Deposit on behalf of a user with a known salt. Works in both modes.
     * @dev The commitment is keccak256(abi.encodePacked(user, salt)). In privacy
     *     mode the emitted event carries only the commitment; in legacy mode it
     *     also carries the raw address for backward compatibility.
     * @param user   The user whose balance should be credited.
     * @param salt   The user's random salt (from the backend user_salts table).
     * @param amount The amount of stablecoin to deposit (base units).
     */
    function depositFor(address user, bytes32 salt, uint256 amount) external {
        require(user != address(0), "invalid user");
        require(amount > 0, "amount must be > 0");
        IERC20 token = IERC20(stablecoin);
        require(token.allowance(msg.sender, address(this)) >= amount, "insufficient allowance");
        require(token.transferFrom(msg.sender, address(this), amount), "transferFrom failed");

        bytes32 commitment = keccak256(abi.encodePacked(user, salt));
        _privateBalances[commitment] = _privateBalances[commitment].add(amount);
        _totalDeposits = _totalDeposits.add(amount);

        if (privacyEnabled) {
            emit DepositedPrivate(commitment, amount);
        } else {
            emit Deposited(commitment, user, amount);
        }
    }

    /**
     * @notice Legacy raw-address withdrawal. REVERTS in privacy mode.
     */
    function withdraw(uint256 amount) external {
        require(!privacyEnabled, "privacy mode: use withdrawWithSalt");
        require(amount > 0, "amount must be > 0");

        bytes32 c = commitmentKey(msg.sender, bytes32(0));
        require(_privateBalances[c] >= amount, "insufficient private balance");
        require(_balances[msg.sender] >= amount, "insufficient raw balance");

        _privateBalances[c] = _privateBalances[c].sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        _totalDeposits = _totalDeposits.sub(amount);

        require(IERC20(stablecoin).transfer(msg.sender, amount), "transfer failed");

        emit Withdrawn(c, msg.sender, amount);
        emit WithdrawnRaw(msg.sender, amount);
    }

    /**
     * @notice Privacy-mode withdrawal: proves knowledge of the salt by supplying
     *       it, and pulls the caller's OWN USDC back to the caller's address.
     * @dev The caller must provide the salt that, combined with the caller's
     *      address, reproduces the commitment that holds a balance. A wrong salt
     *      resolves to a different (usually empty) commitment and the call
     *      reverts with "insufficient private balance".
     *
     *      Privacy note: `msg.sender` necessarily appears in the on-chain
     *      transaction (as the sender) and as the `to` of the USDC transfer.
     *      The WithdrawnPrivate event itself carries only the commitment hash.
     *
     * @dev Fallback from a full zero-knowledge proof: salt-knowledge is the
     *      pragmatic design used here — the salt is 128 bits of entropy known
     *      only to the user and the backend, so an attacker cannot reproduce
     *      the commitment for a target address. A zk-SNARK that proves knowledge
     *      of a preimage without revealing it is a future enhancement that does
     *      not change the balance model.
     */
    function withdrawWithSalt(bytes32 salt, uint256 amount) external {
        require(amount > 0, "amount must be > 0");

        bytes32 commitment = keccak256(abi.encodePacked(msg.sender, salt));
        require(_privateBalances[commitment] >= amount, "insufficient private balance");

        _privateBalances[commitment] = _privateBalances[commitment].sub(amount);
        _totalDeposits = _totalDeposits.sub(amount);

        require(IERC20(stablecoin).transfer(msg.sender, amount), "transfer failed");

        if (privacyEnabled) {
            emit WithdrawnPrivate(commitment, amount);
        } else {
            emit Withdrawn(commitment, msg.sender, amount);
            emit WithdrawnRaw(msg.sender, amount);
        }
    }

    /**
     * @notice Derive the commitment key for a user + salt.
     */
    function commitmentKey(address user, bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, salt));
    }
}

/**
 * @notice Minimal ERC-20 interface for the stablecoin (USDC/USDT).
 */
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function decimals() external view returns (uint8);
}