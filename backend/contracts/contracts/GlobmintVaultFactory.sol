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
 * CREATE2 salt = keccak256(abi.encodePacked(owner)), so `predict(owner)` is
 * stable and the app can show a deposit address before any deploy gas is
 * spent. A clone address on chain is just a hash of (factory, owner) — no
 * personal data is exposed by looking it up.
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

    /// @notice owner -> clone (mapping updated on createClone).
    mapping(address => address) public ownerToClone;

    /// @notice owner -> clone address.
    event CloneCreated(address indexed owner, address indexed clone);

    /// @param stablecoin_ The ERC-20 stablecoin the clones will hold.
    /// @dev The factory deploys its own clone implementation, so the
    ///      implementation's `factory` reference can be this contract without a
    ///      circular deploy step.
    constructor(address stablecoin_) {
        require(stablecoin_ != address(0), "invalid stablecoin");
        stablecoin = stablecoin_;
        implementation = address(new GlobmintVaultClone(stablecoin_, address(this)));
    }

    /// @notice Deterministic clone address for `owner_` (deployed or not).
    function predict(address owner_) public view returns (address) {
        return _predictDeterministicAddress(keccak256(abi.encodePacked(owner_)));
    }

    /// @notice Deploy (idempotently) and return the clone for `owner_`.
    function createClone(address owner_) external returns (address clone) {
        bytes32 salt = keccak256(abi.encodePacked(owner_));
        clone = _predictDeterministicAddress(salt);
        address existing = ownerToClone[owner_];
        if (existing != address(0)) {
            return existing;
        }
        clone = _cloneDeterministic(implementation, salt);
        // Set ownership atomically in the same transaction — no window for
        // anyone to squat on an uninitialized clone.
        GlobmintVaultClone(payable(clone)).initializer(owner_);
        ownerToClone[owner_] = clone;
        emit CloneCreated(owner_, clone);
        return clone;
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