// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title GlobmintVault
/// @notice Non-custodial, per-user stablecoin savings vault.
///
/// Design principles (matching the product vision):
///   - Nobody controls any user's money. There is NO owner, NO admin, and NO
///     function that can seize, transfer, or burn another user's balance.
///   - Each user has their own balance tracked on-chain (`balanceOf`).
///   - Deposits: users `approve` the vault then call `deposit(amount)`; USDC
///     is pulled from the user and credited to their balance.
///   - Withdrawals: any user calls `withdraw(amount)` to pull their OWN USDC
///     back to their own address. Nothing is ever sent to a third party.
///   - No fees are collected by the contract or any operator. The only cost is
///     the network gas the user pays to submit the transaction.
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

/// @notice Minimal ERC-20 interface for the stablecoin (USDC/USDT).
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract GlobmintVault {
    using SafeMath for uint256;

    /// @notice The stablecoin this vault holds (e.g. USDC on Sepolia).
    address public immutable stablecoin;

    /// @notice Per-user USDC balance, in the stablecoin's base units.
    mapping(address => uint256) private _balances;

    /// @notice Total USDC held by the vault across all users.
    uint256 private _totalDeposits;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    /// @param stablecoin_ The ERC-20 stablecoin address (6 decimals for USDC/USDT).
    constructor(address stablecoin_) {
        require(stablecoin_ != address(0), "invalid stablecoin");
        stablecoin = stablecoin_;
    }

    /// @notice The stablecoin base decimals (6 for USDC), exposed for the UI.
    function tokenDecimals() public view returns (uint8) {
        return IERC20(stablecoin).decimals();
    }

    /// @notice USDC balance held for `user`.
    function balanceOf(address user) public view returns (uint256) {
        return _balances[user];
    }

    /// @notice Total USDC held by the vault across all users.
    function totalDeposits() public view returns (uint256) {
        return _totalDeposits;
    }

    /// @notice Deposit `amount` of the stablecoin into the caller's balance.
    /// @dev Requires the caller to have approved this vault for `amount` first.
    function deposit(uint256 amount) external {
        require(amount > 0, "amount must be > 0");
        IERC20 token = IERC20(stablecoin);
        require(
            token.allowance(msg.sender, address(this)) >= amount,
            "insufficient allowance"
        );

        // Pull the stablecoin from the user into the vault.
        require(token.transferFrom(msg.sender, address(this), amount), "transferFrom failed");

        // Credit the user's balance. Mapping arithmetic is checked via SafeMath.
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        _totalDeposits = _totalDeposits.add(amount);

        emit Deposited(msg.sender, amount);
    }

    /// @notice Withdraw `amount` of the stablecoin to the caller's own address.
    /// @dev Only the caller's own balance is affected. Funds are never sent to
    ///      a third party, and no other user's balance can be touched.
    function withdraw(uint256 amount) external {
        require(amount > 0, "amount must be > 0");
        require(_balances[msg.sender] >= amount, "insufficient balance");

        // Debit the user's balance first (CEI: checks-effects-interactions).
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        _totalDeposits = _totalDeposits.sub(amount);

        require(IERC20(stablecoin).transfer(msg.sender, amount), "transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Convenience: deposit on behalf of a user (e.g. a deposit address
    ///         flow). The `depositor` approves and pays; `user` receives credit.
    function depositFor(address user, uint256 amount) external {
        require(user != address(0), "invalid user");
        require(amount > 0, "amount must be > 0");
        IERC20 token = IERC20(stablecoin);
        require(token.allowance(msg.sender, address(this)) >= amount, "insufficient allowance");
        require(token.transferFrom(msg.sender, address(this), amount), "transferFrom failed");

        _balances[user] = _balances[user].add(amount);
        _totalDeposits = _totalDeposits.add(amount);

        emit Deposited(user, amount);
    }

    /// @notice Allow a trusted relayer to deposit on behalf of a user using the
    ///         user's signature (ERC-2612 permit), avoiding double approvals.
    /// @dev Only callable if the stablecoin implements `permit` (EIP-2612).
    ///      Falls back gracefully: if permit is not supported, this reverts.
    function depositWithPermit(
        address user,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(user != address(0), "invalid user");
        require(amount > 0, "amount must be > 0");
        require(deadline >= block.timestamp, "permit expired");

        (bool ok, ) = stablecoin.call(
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
                user, address(this), amount, deadline, v, r, s
            )
        );
        require(ok, "permit failed (token may not support EIP-2612)");

        require(IERC20(stablecoin).transferFrom(user, address(this), amount), "transferFrom failed");
        _balances[user] = _balances[user].add(amount);
        _totalDeposits = _totalDeposits.add(amount);

        emit Deposited(user, amount);
    }
}
