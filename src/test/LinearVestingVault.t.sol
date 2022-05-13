// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {MockBeneficiary} from "./mock/MockBeneficiary.sol";
import {LinearVestingVaultFactory} from "../LinearVestingVaultFactory.sol";
import {LinearVestingVault} from "../LinearVestingVault.sol";

contract LinearVestingVaultTest is DSTestPlus {
    LinearVestingVaultFactory factory;
    LinearVestingVault vault;
    MockERC20 token;
    MockBeneficiary beneficiary;
    uint256 initialTimestamp;

    function setUp() public {
        token = new MockERC20("Mock", "MOCK", 18);
        LinearVestingVault implementation = new LinearVestingVault();
        factory = new LinearVestingVaultFactory(address(implementation));
        beneficiary = new MockBeneficiary();
        initialTimestamp = block.timestamp;
        uint256 amount = 10**18 * 1000;

        token.mint(address(this), amount);
        token.approve(address(factory), amount);
        vault = LinearVestingVault(
            factory.createVault(
                address(token),
                address(beneficiary),
                initialTimestamp,
                initialTimestamp + 100 days,
                amount
            )
        );
    }

    function testInstantiation() public {
        assertEq(address(vault.token()), address(token));
        assertEq(address(vault.beneficiary()), address(beneficiary));
        assertEq(vault.vestStartTimestamp(), initialTimestamp);
        assertEq(vault.vestEndTimestamp(), initialTimestamp + 100 days);
        assertEq(vault.totalAmount(), 10**18 * 1000);

        assertEq(vault.vested(), 0);
        assertEq(
            vault.vestedOn(initialTimestamp + 10 days),
            vault.totalAmount() / 10
        );
        assertEq(
            vault.vestedOn(initialTimestamp + 50 days),
            vault.totalAmount() / 2
        );
        assertEq(
            vault.vestedOn(initialTimestamp + 100 days),
            vault.totalAmount()
        );
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

    function testVestAllThenClaim() public {
        uint256 totalAmount = vault.totalAmount();
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), totalAmount);
        hevm.warp(initialTimestamp + 10 days);
        assertEq(vault.vested(), totalAmount / 10);
        assertEq(vault.unvested(), (totalAmount / 10) * 9);
        hevm.warp(initialTimestamp + 20 days);
        assertEq(vault.vested(), (totalAmount / 10) * 2);
        assertEq(vault.unvested(), (totalAmount / 10) * 8);
        hevm.warp(initialTimestamp + 100 days);
        assertEq(vault.vested(), totalAmount);
        assertEq(vault.unvested(), 0);

        assertClaimAmount(totalAmount);

        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), 0);
    }

    function testClaimPartial() public {
        uint256 totalAmount = vault.totalAmount();

        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), totalAmount);
        hevm.warp(initialTimestamp + 10 days);
        assertEq(vault.vested(), totalAmount / 10);
        assertEq(vault.unvested(), (totalAmount / 10) * 9);
        assertClaimAmount(totalAmount / 10);
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), (totalAmount / 10) * 9);

        hevm.warp(initialTimestamp + 20 days);
        assertEq(vault.vested(), totalAmount / 10);
        assertEq(vault.unvested(), (totalAmount / 10) * 8);
        assertClaimAmount(totalAmount / 10);
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), (totalAmount / 10) * 8);

        hevm.warp(initialTimestamp + 100 days);
        assertEq(vault.vested(), (totalAmount / 10) * 8);
        assertEq(vault.unvested(), 0);
        assertClaimAmount((totalAmount / 10) * 8);
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), 0);
    }

    function testFailInvalidTimestamps() public {
        vault = LinearVestingVault(
            factory.createVault(
                address(token),
                address(beneficiary),
                initialTimestamp + 100 days,
                initialTimestamp + 50 days,
                100
            )
        );
    }

    function testFailClaimUnauthorized(uint256 timestamp) public {
        hevm.warp(timestamp);
        MockBeneficiary fakeBeneficiary = new MockBeneficiary();
        fakeBeneficiary.claim(vault);
    }

    function testFailClaimZero() public {
        assertClaimAmount(0);
    }
}
