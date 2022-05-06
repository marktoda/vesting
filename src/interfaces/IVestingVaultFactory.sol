// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

/**
 * @notice Interface for VestingVault factory contracts
 * vault creation function will have different signature for
 * different vaults given varying parameters
 * so this interface just specifies events, errors, and common
 * functions
 */
interface IVestingVaultFactory {
    event VaultCreated(address token, address beneficiary, address vault);

    /// @notice Some parameters are invalid
    error InvalidParams();
}
