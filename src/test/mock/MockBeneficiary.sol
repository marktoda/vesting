// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IVestingVault} from "../../interfaces/IVestingVault.sol";

contract MockBeneficiary {
    function claim(IVestingVault vault) public {
        vault.claim();
    }
}
