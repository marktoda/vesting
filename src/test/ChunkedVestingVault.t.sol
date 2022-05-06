// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {MockBeneficiary} from "./mock/MockBeneficiary.sol";
import {ChunkedVestingVaultFactory} from "../ChunkedVestingVaultFactory.sol";
import {ChunkedVestingVault} from "../ChunkedVestingVault.sol";

contract ChunkedVestingVaultTest is DSTestPlus {
    ChunkedVestingVaultFactory factory;
    ChunkedVestingVault vault;
    MockERC20 token;
    MockBeneficiary beneficiary;
    uint256 initialTimestamp;

    function setUp() public {
        token = new MockERC20("Mock", "MOCK", 18);
        ChunkedVestingVault implementation = new ChunkedVestingVault();
        factory = new ChunkedVestingVaultFactory(address(implementation));
        beneficiary = new MockBeneficiary();
        initialTimestamp = block.timestamp;

        token.mint(address(this), 300);
        token.approve(address(factory), 300);
        vault = ChunkedVestingVault(
            factory.createVault(
                address(token),
                address(beneficiary),
                makeArray(100, 100, 100),
                makeArray(
                    initialTimestamp + 1 days,
                    initialTimestamp + 2 days,
                    initialTimestamp + 3 days
                )
            )
        );
    }

    function testInstantiation() public {
        assertEq(address(vault.token()), address(token));
        assertEq(address(vault.beneficiary()), address(beneficiary));
        assertEq(vault.vestingPeriods(), 3);

        assertUintArrayEq(vault.amounts(), makeArray(100, 100, 100));
        assertUintArrayEq(
            vault.timestamps(),
            makeArray(
                initialTimestamp + 1 days,
                initialTimestamp + 2 days,
                initialTimestamp + 3 days
            )
        );
        assertEq(vault.vestedChunks(), 0);
        assertEq(vault.vested(), 0);
        assertEq(vault.vestedOn(initialTimestamp + 1 days), 100);
        assertEq(vault.vestedOn(initialTimestamp + 2 days), 200);
        assertEq(vault.vestedOn(initialTimestamp + 3 days), 300);
    }

    function testVestAllThenClaim() public {
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), 300);
        hevm.warp(initialTimestamp + 1 days);
        assertEq(vault.vested(), 100);
        assertEq(vault.unvested(), 200);
        hevm.warp(initialTimestamp + 2 days);
        assertEq(vault.vested(), 200);
        assertEq(vault.unvested(), 100);
        hevm.warp(initialTimestamp + 3 days);
        assertEq(vault.vested(), 300);
        assertEq(vault.unvested(), 0);

        assertClaimAmount(300);

        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), 0);
    }

    function testClaimPartial() public {
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), 300);
        hevm.warp(initialTimestamp + 1 days);
        assertEq(vault.vested(), 100);
        assertEq(vault.unvested(), 200);
        assertClaimAmount(100);
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), 200);

        hevm.warp(initialTimestamp + 2 days);
        assertEq(vault.vested(), 100);
        assertEq(vault.unvested(), 100);
        assertClaimAmount(100);
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), 100);

        hevm.warp(initialTimestamp + 3 days);
        assertEq(vault.vested(), 100);
        assertEq(vault.unvested(), 0);
        assertClaimAmount(100);
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), 0);
    }

    function testWarpAndClaim(uint256 timestamp) public {
        hevm.warp(timestamp);
        if (timestamp >= initialTimestamp + 3 days) {
            assertClaimAmount(300);
        } else if (timestamp >= initialTimestamp + 2 days) {
            assertClaimAmount(200);
        } else if (timestamp >= initialTimestamp + 1 days) {
            assertClaimAmount(100);
        } else {
            assertEq(vault.vested(), 0);
        }
    }

    function testFailClaimUnauthorized(uint256 timestamp) public {
        hevm.warp(timestamp);
        MockBeneficiary fakeBeneficiary = new MockBeneficiary();
        fakeBeneficiary.claim(vault);
    }

    function testFailClaimZero() public {
        assertClaimAmount(0);
    }

    function assertClaimAmount(uint256 amount) internal {
        assertEq(vault.vested(), amount);
        uint256 initialBalance = token.balanceOf(address(beneficiary));
        uint256 initialVaultBalance = token.balanceOf(address(vault));
        beneficiary.claim(vault);
        assertEq(
            initialBalance + amount,
            token.balanceOf(address(beneficiary))
        );
        assertEq(initialVaultBalance - amount, token.balanceOf(address(vault)));
    }

    function makeArray(
        uint256 a,
        uint256 b,
        uint256 c
    ) internal pure returns (uint256[] memory) {
        uint256[] memory result = new uint256[](3);
        result[0] = a;
        result[1] = b;
        result[2] = c;
        return result;
    }
}
