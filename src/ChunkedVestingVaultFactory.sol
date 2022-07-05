// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {ChunkedVestingVault} from "./ChunkedVestingVault.sol";
import {IVestingVaultFactory} from "./interfaces/IVestingVaultFactory.sol";

contract ChunkedVestingVaultFactory is IVestingVaultFactory {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ClonesWithImmutableArgs for address;

    address public immutable implementation;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    /**
     * @notice Creates a new vesting vault
     * @param token The ERC20 token to vest over time
     * @param beneficiary The address who will receive tokens over time
     * @param admin The address that can claw claw back unvested funds
     * @param amounts The amounts to be vested per chunk.
     *  This is assumed to be sorted in unlock order
     * @param timestamps The amounts to be vested per chunk.
     *  This is assumed to be sorted in ascending time order
     */
    function createVault(
        address token,
        address beneficiary,
        address admin,
        uint256[] calldata amounts,
        uint256[] calldata timestamps
    ) public returns (address) {
        if (amounts.length != timestamps.length) revert InvalidParams();

        bytes memory data = abi.encodePacked(
            token,
            beneficiary,
            amounts.length,
            amounts,
            timestamps
        );
        ChunkedVestingVault clone = ChunkedVestingVault(
            implementation.clone(data)
        );

        uint256 totalTokens = clone.vestedOn(type(uint256).max);
        IERC20Upgradeable(token).safeTransferFrom(
            msg.sender,
            address(this),
            totalTokens
        );
        IERC20Upgradeable(token).approve(address(clone), totalTokens);

        clone.initialize(admin);

        emit VaultCreated(token, beneficiary, address(clone));
        return address(clone);
    }
}
