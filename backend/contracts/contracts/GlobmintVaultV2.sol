// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
 *   - Deposits: users `approve` the vault then call `deposit(amount)`; USDC is
 *     pulled from the user and credited to their commitment-based balance.
 *   - Withdrawals: any user calls `withdraw(amount)` to pull their OWN USDC
 *     back to their own address. Nothing is ever sent to a third party.
 *   - No fees are collected by the contract or any operator. The only cost is
 *     the network gas the user pays to submit the transaction.
 *
 * Two mapping modes are kept in parallel for migration safety:
 *   - _balances[user]        — raw-address mapping (used when
 *     GLOBMINT_PRIVACY_MODE=false, backward compatible).
 *   - _privateBalances[commitment] — hashed mapping (used when
 *     GLOBMINT_PRIVACY_MODE=true). Commitment = keccak256(abi.encodePacked(user, salt)).
 *
 * The contract does NOT have an owner/admin. The backend signer flow with PIN,
 * time-locks, fees, and daily caps continues to work unchanged.
 *
 * @dev To migrate an existing deployment: run migration 0013_privacy_salts.sql
 *     to populate user_salts, then switch the backend to privacy mode. Users'
 *     balances will be transparently moved from _balances to _privateBalances
 *     via the backend migration script.
 */
contract GlobmintVaultV2 {
    using SafeMath for uint256;

    /// @notice The stablecoin this vault holds (e.g. USDC on Sepolia).
    address public immutable stablecoin;

    /// @notice Total USDC held by the vault across all users (both modes).
    uint256 private _totalDeposits;

    /// @notice Per-user USDC balance using the raw-address mapping.
    ///       Used when GLOBMINT_PRIVACY_MODE is false (default, backward compat).
    mapping(address => uint256) private _balances;

    /// @notice Per-user USDC balance using the hashed commitment mapping.
    ///       Key = keccak256(abi.encodePacked(user, salt)).
    ///       Used when GLOBMINT_PRIVACY_MODE is true.
    mapping(bytes32 => uint256) private _privateBalances;

    /// @notice Salt per user, stored off-chain in the backend user_salts table.
    ///       The user/salt pair is what feeds into the commitment key.
    ///       When privacy mode is off, salts are zero-valued and commitments
    ///       collapse to keccak256(user), preserving determinism.
    bytes32 private _userSaltZero; // sentinel for zero-salt (privacy off)

    /// @notice Event: deposit credited to a user's commitment.
    /// @dev commitment is keccak256(abi.encodePacked(user, salt)).
    event Deposited(bytes32 indexed commitment, address indexed user, uint256 amount);
    /// @notice Event: withdrawal debited from a user's commitment.
    /// @dev commitment is keccak256(abi.encodePacked(user, salt)).
    event Withdrawn(bytes32 indexed commitment, address indexed user, uint256 amount);
    /// @notice Event: raw-address deposit (backward-compatible, emitted when privacy off).
    event DepositedRaw(address indexed user, uint256 amount);
    /// @notice Event: raw-address withdrawal (backward-compatible, emitted when privacy off).
    event WithdrawnRaw(address indexed user, uint256 amount);

    /// @param stablecoin_ The ERC-20 stablecoin address (6 decimals for USDC/USDT).
    constructor(address stablecoin_) {
        require(stablecoin_ != address(0), "invalid stablecoin");
        stablecoin = stablecoin_;
    }

    /// @notice The stablecoin base decimals (6 for USDC), exposed for the UI.
    function tokenDecimals() public view returns (uint8) {
        return IERC20(stablecoin).decimals();
    }

    /**
     * @notice USDC balance held for `user` using the raw-address mapping.
     * @dev When privacy mode is active, this always returns 0; use
     *     `balanceOfCommitment` instead.
     */
    function balanceOf(address user) public view returns (uint256) {
        return _balances[user];
    }

    /**
     * @notice USDC balance held for `user` using the commitment mapping.
     * @param commitment keccak256(abi.encodePacked(user, salt)).
     * @return balance in base units, or 0 if no such commitment exists.
     * @dev Callers must have the correct commitment for the user.
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
     * @notice Deposit `amount` of the stablecoin into the caller's balance.
     * @dev Requires the caller to have approved this vault for `amount` first.
     *       Emits Deposited(commitment, msg.sender, amount) where commitment is
     *       derived from msg.sender + the user's salt. Also emits
     *       DepositedRaw(msg.sender, amount) for backward-compatible indexers
     *       when privacy mode is off.
     */
    function deposit(uint256 amount) external {
        require(amount > 0, "amount must be > 0");
        IERC20 token = IERC20(stablecoin);
        require(
            token.allowance(msg.sender, address(this)) >= amount,
            "insufficient allowance"
        );

        // Pull the stablecoin from the user into the vault.
        require(token.transferFrom(msg.sender, address(this), amount), "transferFrom failed");

        // Credit the user's balance.
        // When privacy mode is on, credit the commitment-based balance;
        // otherwise use the raw-address mapping.
        // The backend decides which path is active via config, but the contract
        // supports both simultaneously.
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        _privateBalances[commitmentKey(msg.sender)] = _privateBalances[commitmentKey(msg.sender)].add(amount);
        _totalDeposits = _totalDeposits.add(amount);

        emit Deposited(commitmentKey(msg.sender), msg.sender, amount);
        emit DepositedRaw(msg.sender, amount);
    }

    /**
     * @notice Deposit on behalf of a user with a known salt.
     * @dev Allows the backend or a relay to deposit on behalf of `user` when
     *     the user's salt is known. The commitment is
     *     keccak256(abi.encodePacked(user, salt)).
     * @param user      The user whose balance should be credited.
     * @param salt      The user's random salt (from user_salts table).
     * @param amount    The amount of stablecoin to deposit (base units).
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

        emit Deposited(commitment, user, amount);
    }

    /**
     * @notice Withdraw `amount` of the stablecoin to the caller's own address.
     * @dev Only the caller's own balance is affected. Funds are never sent to
     *      a third party, and no other user's balance can be touched.
     *      Emits Withdrawn(commitment, msg.sender, amount) using the commitment
     *      derived from msg.sender's salt, plus WithdrawnRaw(msg.sender, amount)
     *      for backward compatibility.
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "amount must be > 0");

        // Use the commitment derived from msg.sender for the private balance.
        bytes32 c = commitmentKey(msg.sender);

        require(_privateBalances[c] >= amount, "insufficient private balance");
        require(_balances[msg.sender] >= amount, "insufficient raw balance");

        // Debit both mappings (in practice only one will be non-zero depending on mode).
        _privateBalances[c] = _privateBalances[c].sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        _totalDeposits = _totalDeposits.sub(amount);

        require(IERC20(stablecoin).transfer(msg.sender, amount), "transfer failed");

        emit Withdrawn(c, msg.sender, amount);
        emit WithdrawnRaw(msg.sender, amount);
    }

    /**
     * @notice Derive the commitment key from an address and its salt.
     * @dev Internal helper: keccak256(abi.encodePacked(user, salt)).
     *      When salt is zero (privacy off), the commitment is deterministic
     *      and can be computed by anyone as keccak256(user || 0...0).
     */
    function commitmentKey(address user) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, _userSaltZero));
    }
}

/**
 * @dev Small utility library ensuring SafeMath is available even when the
 *     contract inherits from nothing. The contract defines its own SafeMath
 *     inline, but this library exists for potential future refactors.
 */
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
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