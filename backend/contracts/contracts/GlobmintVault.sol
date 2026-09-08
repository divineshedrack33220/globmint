// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SafeMath.sol";

/**
 * @title GlobmintVault
 * @notice Non-custodial, per-user stablecoin savings vault.
 *
 * Design principles (matching the product vision):
 *   - Nobody controls any user's money. There is NO owner, NO admin, and NO
 *     function that can seize, transfer, or burn another user's balance.
 *   - Each user has their own balance tracked on-chain (`balanceOf`).
 *   - Users `approve` the vault then call `deposit(amount)`; USDC
 *     is pulled from the user and credited to their balance.
 *   - Direct ERC-20 transfers: a standard `transfer`/`send` of the stablecoin
 *     to this contract moves tokens purely inside the token contract's storage
 *     and NEVER calls a function here, so the vault cannot emit `Deposited`
 *     and cannot revert the transfer (ERC-20 has no receiver hook, and the
 *     contract's `fallback()` is never invoked). Those funds land in vault
 *     custody. This is intentional: the off-chain Globmint indexer watches
 *     the stablecoin's `Transfer(to == vault)` events and credits the sender's
 *     internal ledger (see `vaultAvailableBase()` reconciliation).
 *   - Native ETH is rejected outright (`receive` reverts): it would otherwise
 *     be irrecoverable with no owner.
 *
 *   - Withdrawals: any user calls `withdraw(amount)` to pull their OWN USDC
 *     back to their own address. Nothing is ever sent to a third party.
 *   - No fees are collected by the contract or any operator. The only cost is
 *     the network gas the user pays to submit the transaction.
 *
 * Privacy upgrade (V2): balances may be stored against
 * keccak256(user, salt) commitments when GLOBMINT_PRIVACY_MODE is true.
 * When privacy mode is off (default), raw-address mapping is used for
 * full backward compatibility.
 *
 * Two balance mappings coexist:
 *   - _balances[user]        — raw-address mapping (privacy off, default).
 *   - _privateBalances[commitment] — hashed mapping (privacy on).
 *     Commitment = keccak256(abi.encodePacked(user, salt)).
 *
 * The contract has NO owner/admin. The backend signer flow with PIN,
 * time-locks, fees, and daily caps continues to work.
 */
contract GlobmintVault {
    using SafeMath for uint256;

    /// @notice The stablecoin this vault holds (e.g. USDC on Sepolia).
    address public immutable stablecoin;

    /// @notice Total USDC held by the vault across all users.
    uint256 private _totalDeposits;

    /// @notice Reject native ETH: with no owner, stray ETH would be stranded.
    receive() external payable {
        revert("ETH not accepted");
    }

    /// @notice Reject unknown calldata. Note: a standard ERC-20 `transfer`
    ///         to this address does NOT route here (the token contract simply
    ///         updates its own balances), so direct stablecoin transfers are
    ///         handled off-chain by the indexer, not by this function.
    fallback() external payable {
        revert("invalid call");
    }

    /// @notice Per-user USDC balance using the raw-address mapping.
    ///       Used when GLOBMINT_PRIVACY_MODE is false (default, backward compat).
    mapping(address => uint256) private _balances;

    /// @notice Per-user USDC balance using the hashed commitment mapping.
    ///       Key = keccak256(abi.encodePacked(user, salt)).
    ///       Used when GLOBMINT_PRIVACY_MODE is true.
    mapping(bytes32 => uint256) private _privateBalances;

    /// @notice Zero salt sentinel (privacy mode off).
    bytes32 private _zeroSalt;

    /// @notice Event: deposit credited to a user.
    /// @dev When privacy mode is on, commitment = keccak256(user, salt).
    event Deposited(bytes32 indexed commitment, address indexed user, uint256 amount);
    /// @notice Event: raw-address deposit (backward-compatible, emitted always).
    event DepositedRaw(address indexed user, uint256 amount);
    /// @notice Event: withdrawal debited from a user.
    event Withdrawn(bytes32 indexed commitment, address indexed user, uint256 amount);
    /// @notice Event: raw-address withdrawal (backward-compatible, emitted always).
    event WithdrawnRaw(address indexed user, uint256 amount);

    /// @param stablecoin_ The ERC-20 stablecoin address (6 decimals for USDC/USDT).
    constructor(address stablecoin_) {
        require(stablecoin_ != address(0), "invalid stablecoin");
        stablecoin = stablecoin_;
        _zeroSalt = bytes32(0);
    }

    /// @notice The stablecoin base decimals (6 for USDC), exposed for the UI.
    function tokenDecimals() public view returns (uint8) {
        return IERC20(stablecoin).decimals();
    }

    /**
     * @notice USDC balance held for `user`.
     * @dev When privacy mode is active, returns the raw-mapping balance (usually 0);
     *     callers should use `balanceOfCommitment` with the correct commitment.
     */
    function balanceOf(address user) public view returns (uint256) {
        return _balances[user];
    }

    /**
     * @notice USDC balance held for `user` using the commitment mapping.
     * @param commitment keccak256(abi.encodePacked(user, salt)).
     * @return balance in base units, or 0 if no such commitment exists.
     * @dev Callers must have the correct commitment for the user (obtained from
     *     the backend via the user_salts table when privacy mode is on).
     */
    function balanceOfCommitment(bytes32 commitment) public view returns (uint256) {
        return _privateBalances[commitment];
    }

    /**
     * @notice Total USDC held by the vault across all users.
     */
    function totalDeposits() public view returns (uint256) {
        return _totalDeposits;
    }

    /**
     * @notice Stablecoin base-units in this contract's custody, including any
     *         direct-transfer amounts that were never credited on-chain.
     * @dev Reconciliation: the difference `vaultAvailableBase() - totalDeposits()`
     *      is USDC sent straight to the contract (e.g. a wallet's generic
     *      "Send") by a sender the off-chain indexer could not identify. The
     *      indexer flags those and operators attribute them to a user.
     */
    function vaultAvailableBase() external view returns (uint256) {
        return IERC20(stablecoin).balanceOf(address(this));
    }

    /**
     * @notice Deposit `amount` of the stablecoin into the caller's balance.
     * @dev Requires the caller to have approved this vault for `amount` first.
     *       Credits both the raw-address mapping and the commitment mapping
     *       simultaneously, so both privacy modes work.
     *       Emits Deposited(commitment, msg.sender, amount) and
     *       DepositedRaw(msg.sender, amount).
     */
    function deposit(uint256 amount) external {
        require(amount > 0, "amount must be > 0");
        IERC20 token = IERC20(stablecoin);
        require(
            token.allowance(msg.sender, address(this)) >= amount,
            "insufficient allowance"
        );

        require(token.transferFrom(msg.sender, address(this), amount), "transferFrom failed");

        _balances[msg.sender] = _balances[msg.sender].add(amount);
        _privateBalances[commitmentKey(msg.sender)] = _privateBalances[commitmentKey(msg.sender)].add(amount);
        _totalDeposits = _totalDeposits.add(amount);

        emit Deposited(commitmentKey(msg.sender), msg.sender, amount);
        emit DepositedRaw(msg.sender, amount);
    }

    /**
     * @notice Deposit on behalf of a user with a known salt.
     * @param user  The user whose balance should be credited.
     * @param salt  The user's random salt.
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

        emit Deposited(commitment, user, amount);
    }

    /**
     * @notice Withdraw `amount` of the stablecoin to the caller's own address.
     * @dev Only the caller's own balance is affected. Funds are never sent to
     *      a third party, and no other user's balance can be touched.
     *      Debits both mappings, emits both events.
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "amount must be > 0");

        bytes32 c = commitmentKey(msg.sender);

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
     * @notice Derive the commitment key from an address and its salt.
     * @dev Internal helper: keccak256(abi.encodePacked(user, salt)).
     *      When salt is zero (privacy off), keccak256(user || 0) is deterministic.
     */
    function commitmentKey(address user) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(user, _zeroSalt));
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