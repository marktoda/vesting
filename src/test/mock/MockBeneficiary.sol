// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;
import {ChunkedVestingVault} from "../../ChunkedVestingVault.sol";

contract MockBeneficiary {
    function claim(ChunkedVestingVault vault) public {
        vault.claim();
    }
}
