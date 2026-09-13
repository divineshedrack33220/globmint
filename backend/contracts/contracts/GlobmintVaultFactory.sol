// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./GlobmintVaultClone.sol";

/**
 * @title GlobmintVaultFactory
 * @notice Deploys one EIP-1167 minimal-proxy clone per Globmint account via
 *         CREATE2, giving every account a deterministic, private deposit
 *         address. The factory itself never holds funds and has no withdrawal
 *         authority — each clone is owned by its account.
 *
 * Uniqueness: the CREATE2 salt is derived from a PER-USER KEY (a bytes32 the
 * backend derives from the account id, e.g. keccak256(userID)), NOT from the
 * clone's owner. This matters because an account may not have its own wallet
 * yet — the owner seat is then held by the platform signer so funds are never
 * locked, and the user can later claim the clone via transferOwnershipBySig.
 * If the salt were keccak256(owner), every signer-owned (unlinked) account
 * would resolve to the SAME address. With a per-user key every account's
 * address is unique, stable across re-links, and needs no wallet to receive.
 *
 * `predict(userKey)` is pure deterministic address math, so the app can show a
 * deposit address before any deploy gas is spent. A clone address on chain is
 * just a hash of (factory, userKey) — no personal data is exposed by looking
 * it up.
 *
 * The clone deployment bytecode + address prediction use the canonical minimal
 * proxy construction (OpenZeppelin v5 Clones, MIT) to guarantee deploy() and
 * predict() never disagree; this is vendored here so the repo keeps its
 * zero-OZ-dependency build.
 */
contract GlobmintVaultFactory {
    /// @notice Implementation whose runtime code every clone delegatecalls.
    address public immutable implementation;
    /// @notice Stablecoin the clones hold.
    address public immutable stablecoin;
    /// @notice Privacy policy applied to every clone this factory deploys:
    ///         clones boot with commitment-based balances (depositFor/
    ///         withdrawWithSalt) when true. Fixed at deploy time; the whole
    ///         fleet follows one policy so the indexer can rely on a match.
    bool public immutable initialPrivacy;

    /// @notice per-user deployment key -> clone (mapping updated on createClone).
    mapping(bytes32 => address) public cloneOfUser;

    /// @notice a per-user clone was created.
    event CloneCreated(bytes32 indexed userKey, address indexed owner, address indexed clone);

    /// @param stablecoin_ The ERC-20 stablecoin the clones will hold.
    /// @param initialPrivacy_ Whether newly deployed clones boot in privacy mode.
    /// @dev The factory deploys its own clone implementation, so the
    ///      implementation's `factory` reference can be this contract without a
    ///      circular deploy step.
    constructor(address stablecoin_, bool initialPrivacy_) {
        require(stablecoin_ != address(0), "invalid stablecoin");
        stablecoin = stablecoin_;
        initialPrivacy = initialPrivacy_;
        implementation = address(new GlobmintVaultClone(stablecoin_, address(this)));
    }

    /// @notice Deterministic clone address for `userKey_` (deployed or not).
    function predict(bytes32 userKey_) public view returns (address) {
        return _predictDeterministicAddress(_salt(userKey_));
    }

    /// @notice Deploy (idempotently) and return the clone for `userKey_`, owned
    ///         by `owner_` (the account's wallet, or the platform signer as a
    ///         placeholder the user can later claim).
    function createClone(bytes32 userKey_, address owner_) external returns (address clone) {
        require(owner_ != address(0), "invalid owner");
        bytes32 salt = _salt(userKey_);
        clone = _predictDeterministicAddress(salt);
        address existing = cloneOfUser[userKey_];
        if (existing != address(0)) {
            return existing;
        }
        clone = _cloneDeterministic(implementation, salt);
        // Set ownership atomically in the same transaction — no window for
        // anyone to squat on an uninitialized clone. Apply the fleet privacy
        // policy so every clone boots in the same mode the indexer expects.
        GlobmintVaultClone(payable(clone)).initializer(owner_);
        GlobmintVaultClone(payable(clone)).setPrivacyEnabled(initialPrivacy);
        cloneOfUser[userKey_] = clone;
        emit CloneCreated(userKey_, owner_, clone);
        return clone;
    }

    /// @notice Toggle the direct-owner-withdraw kill-switch for one clone. The
    ///         clone's setter only accepts the factory as caller; this is the
    ///         operator lever that flips the fleet from "owner can withdraw
    ///         directly" to "withdrawals require the owner's EIP-712 signature"
    ///         (withdrawWithSig) without locking funds — the relay path stays
    ///         open. Default (zeroed storage) is enabled.
    function setDirectWithdrawDisabled(address clone_, bool disabled) external {
        GlobmintVaultClone(payable(clone_)).setDirectWithdrawDisabled(disabled);
    }

    /// @notice Arm (or disarm) the time-locked recovery window for one clone —
    ///         the factory holds this lever so the operator can set the fleet
    ///         policy without needing each clone owner's key. Delay is in
    ///         seconds; 0 disarms any pending recovery.
    function setRecoveryDelay(address clone_, uint256 delay) external {
        GlobmintVaultClone(payable(clone_)).setRecoveryDelay(delay);
    }

    function _salt(bytes32 userKey_) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(userKey_));
    }

    function _cloneDeterministic(address impl, bytes32 salt) internal returns (address instance) {
        assembly ("memory-safe") {
            // OZ v5 Clones.cloneDeterministic bytecode construction.
            mstore(0x00, or(shr(232, shl(96, impl)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            mstore(0x20, or(shl(120, impl), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create2(0, 0x09, 0x37, salt)
        }
        require(instance != address(0), "clone deployment failed");
    }

    function _predictDeterministicAddress(bytes32 salt) internal view returns (address predicted) {
        address impl = implementation;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x38), address())
            mstore(add(ptr, 0x24), 0x5af43d82803e903d91602b57fd5bf3ff)
            mstore(add(ptr, 0x14), impl)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
            mstore(add(ptr, 0x58), salt)
            mstore(add(ptr, 0x78), keccak256(add(ptr, 0x0c), 0x37))
            predicted := and(keccak256(add(ptr, 0x43), 0x55), 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }
}