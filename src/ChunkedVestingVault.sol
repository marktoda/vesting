// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {VestingVault} from "./VestingVault.sol";

/**
 * @notice VestingVault contract for a series of chunked token releases
 * @dev immutable args:
 *  - slot 0 - address token (20 bytes) (in VestingVault)
 *  - slot 1 - address beneficiary (20 bytes) (in VestingVault)
 *  - slot 2 - uint256 vestingPeriods
 *  - slot 3-x - uint256[] amounts
 *  - slot x-y - uint256[] timestamps
 */
contract ChunkedVestingVault is VestingVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @notice The token which is being vested
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return the token which is being vested
     */
    function vestingPeriods() public pure returns (uint256) {
        // starts at 40 because of the parent VestingVault uses bytes 0-39 for token and beneficiary
        return _getArgUint256(40);
    }

    /**
     * @notice The array of chunked amounts to be vested
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @return the array of chunked amounts to be vested
     */
    function amounts() public pure returns (uint256[] memory) {
        return _getArgUint256Array(72, uint64(vestingPeriods()));
    }

    /**
     * @notice The array of timestamps at which chunks of tokens are vested
     * @dev using ClonesWithImmutableArgs pattern here to save gas
     * @dev https://github.com/wighawag/clones-with-immutable-args
     * @dev These are expected to be already sorted in timestamp order
     * @return the timestamps at which chunks of tokens are vested
     */
    function timestamps() public pure returns (uint256[] memory) {
        return
            _getArgUint256Array(
                72 + (32 * vestingPeriods()),
                uint64(vestingPeriods())
            );
    }

    /// @notice The number of vesting chunks used up so far
    uint256 public vestedChunks;

    /**
     * @notice Initializes the vesting vault
     * @dev this is separate from initialize() so an inheritor can
     *  override the initializer without breaking the reentrancy protection in
     *  `initializer`. for more info read
     *  https://github.com/OpenZeppelin/openzeppelin-contracts/commit/553c8fdec708ea10dd5f4a2977364af7a562566f
     */
    function initialize() public virtual initializer {
        _initialize();
    }

    /**
     * @notice Initializes the vesting vault
     * @dev this pulls in the required ERC20 tokens from the sender to setup
     */
    function _initialize() internal onlyInitializing {
        // calculate total amount of tokens over the lifetime of the vault
        (uint256 amount, uint256 chunks) = getVestedAmountAndChunks(
            type(uint256).max
        );
        if (chunks != vestingPeriods()) revert InvalidParams();

        VestingVault.initialize(amount);
    }

    /**
     * @inheritdoc VestingVault
     */
    function vestedOn(uint256 timestamp)
        public
        view
        override
        returns (uint256 amount)
    {
        (amount, ) = getVestedAmountAndChunks(timestamp);
    }

    /**
     * @inheritdoc VestingVault
     */
    function onClaim(uint256 amount) internal virtual override {
        (uint256 total, uint256 chunks) = getVestedAmountAndChunks(
            block.timestamp
        );
        if (amount != total) revert InvalidClaim();
        vestedChunks = chunks;
    }

    /**
     * @notice helper function to get the currently vested amount of tokens
     * and the total number of vesting chunks that have been used so far
     * @return amount The amount of tokens currently vested
     * @return chunks The total number of chunks used so far
     */
    function getVestedAmountAndChunks(uint256 timestamp)
        internal
        view
        returns (uint256 amount, uint256 chunks)
    {
        uint256[] memory _amounts = amounts();
        uint256[] memory _timestamps = timestamps();

        uint256 total;
        for (uint256 i = vestedChunks; i < vestingPeriods(); i++) {
            if (timestamp >= _timestamps[i]) {
                // then we have vested this chunk
                total += _amounts[i];
            } else {
                // return early because we haven't gotten this far in the vesting cycle yet
                return (total, i);
            }
        }
        return (total, vestingPeriods());
    }
}
