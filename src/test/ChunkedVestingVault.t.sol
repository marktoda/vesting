// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {MockBeneficiary} from "./mock/MockBeneficiary.sol";
import {ChunkedVestingVaultFactory} from "../ChunkedVestingVaultFactory.sol";
import {ChunkedVestingVault} from "../ChunkedVestingVault.sol";
import {IVestingVault} from "../interfaces/IVestingVault.sol";

contract ChunkedVestingVaultTest is Test {
    ChunkedVestingVaultFactory factory;
    ChunkedVestingVault vault;
    ChunkedVestingVault clawbackVault;
    MockERC20 token;
    MockBeneficiary beneficiary;
    uint256 initialTimestamp;

    function setUp() public {
        token = new MockERC20("Mock", "MOCK", 18);
        ChunkedVestingVault implementation = new ChunkedVestingVault();
        factory = new ChunkedVestingVaultFactory(address(implementation));
        beneficiary = new MockBeneficiary();
        initialTimestamp = block.timestamp;

        token.mint(address(this), 600);
        token.approve(address(factory), 600);
        vault = ChunkedVestingVault(
            factory.createVault(
                address(token),
                address(beneficiary),
                address(0),
                makeArray(100, 100, 100),
                makeArray(
                    initialTimestamp + 1 days,
                    initialTimestamp + 2 days,
                    initialTimestamp + 3 days
                )
            )
        );

        clawbackVault = ChunkedVestingVault(
            factory.createVault(
                address(token),
                address(beneficiary),
                address(this),
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

    function testRevertReinitialize() public {
        vm.expectRevert("Initializable: contract is already initialized");
        vault.initialize(address(this));
    }

    function testVestAllThenClaim() public {
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), 300);
        vm.warp(initialTimestamp + 1 days);
        assertEq(vault.vested(), 100);
        assertEq(vault.unvested(), 200);
        vm.warp(initialTimestamp + 2 days);
        assertEq(vault.vested(), 200);
        assertEq(vault.unvested(), 100);
        vm.warp(initialTimestamp + 3 days);
        assertEq(vault.vested(), 300);
        assertEq(vault.unvested(), 0);

        assertClaimAmount(300);

        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), 0);
    }

    function testClaimPartial() public {
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), 300);
        vm.warp(initialTimestamp + 1 days);
        assertEq(vault.vested(), 100);
        assertEq(vault.unvested(), 200);
        assertClaimAmount(100);
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), 200);

        vm.warp(initialTimestamp + 2 days);
        assertEq(vault.vested(), 100);
        assertEq(vault.unvested(), 100);
        assertClaimAmount(100);
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), 100);

        vm.warp(initialTimestamp + 3 days);
        assertEq(vault.vested(), 100);
        assertEq(vault.unvested(), 0);
        assertClaimAmount(100);
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), 0);
    }

    function testWarpAndClaim(uint256 timestamp) public {
        vm.warp(timestamp);
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

    function testSingleUnlock(uint256 amount) public {
        // throws on amount 0, tested below
        if (amount == 0) amount = 1;
        uint256 totalSupply = token.totalSupply();
        // otherwise we overflow the token
        if (amount > type(uint256).max - totalSupply)
            amount = type(uint256).max - totalSupply;
        token.mint(address(this), amount);
        token.approve(address(factory), amount);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory timestamps = new uint256[](1);
        amounts[0] = amount;
        timestamps[0] = initialTimestamp + (4 * 86400 * 365);
        vault = ChunkedVestingVault(
            factory.createVault(
                address(token),
                address(beneficiary),
                address(0),
                amounts,
                timestamps
            )
        );
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), amount);
        vm.warp(initialTimestamp + (1 * 86400 * 365));
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), amount);
        vm.warp(initialTimestamp + (2 * 86400 * 365));
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), amount);
        vm.warp(initialTimestamp + (3 * 86400 * 365));
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), amount);

        vm.warp(initialTimestamp + (4 * 86400 * 365));
        assertEq(vault.vested(), amount);
        assertEq(vault.unvested(), 0);

        assertClaimAmount(amount);
    }

    // note: can parameterize count & amountPerUnlock,
    // but it is very slow
    // function testManyUnlocks(uint8 count, uint64 amountPerUnlock) public {
    function testManyUnlocks() public {
        uint16 count = 500;
        uint256 amountPerUnlock = 12341234;
        uint256[] memory amounts = new uint256[](count);
        uint256[] memory timestamps = new uint256[](count);
        token.mint(address(this), uint256(count) * amountPerUnlock);
        token.approve(address(factory), uint256(count) * amountPerUnlock);
        for (uint256 i = 0; i < count; i++) {
            amounts[i] = amountPerUnlock;
            timestamps[i] = initialTimestamp + ((i + 1) * 86400);
        }

        vault = ChunkedVestingVault(
            factory.createVault(
                address(token),
                address(beneficiary),
                address(0),
                amounts,
                timestamps
            )
        );

        for (uint256 i = 0; i < count; i++) {
            vm.warp(initialTimestamp + ((i + 1) * 86400));
            assertClaimAmount(amountPerUnlock);
        }
    }

    function testDifferingAmounts() public {
        uint256 total = 100 + 300 + 500;
        token.mint(address(this), total);
        token.approve(address(factory), total);
        vault = ChunkedVestingVault(
            factory.createVault(
                address(token),
                address(beneficiary),
                address(0),
                makeArray(100, 300, 500),
                makeArray(
                    initialTimestamp + 1 days,
                    initialTimestamp + 2 days,
                    initialTimestamp + 3 days
                )
            )
        );
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), 900);
        vm.warp(initialTimestamp + 1 days);
        assertEq(vault.vested(), 100);
        assertEq(vault.unvested(), 800);
        assertClaimAmount(100);
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), 800);

        vm.warp(initialTimestamp + 2 days);
        assertEq(vault.vested(), 300);
        assertEq(vault.unvested(), 500);
        assertClaimAmount(300);
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), 500);

        vm.warp(initialTimestamp + 3 days);
        assertEq(vault.vested(), 500);
        assertEq(vault.unvested(), 0);
        assertClaimAmount(500);
        assertEq(vault.vested(), 0);
        assertEq(vault.unvested(), 0);
    }

    function testFailTooManyAmounts() public {
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;
        amounts[3] = 400;
        vault = ChunkedVestingVault(
            factory.createVault(
                address(token),
                address(beneficiary),
                address(0),
                amounts,
                makeArray(
                    initialTimestamp + 1 days,
                    initialTimestamp + 2 days,
                    initialTimestamp + 3 days
                )
            )
        );
    }

    function testFailTooManyTimestamps() public {
        uint256[] memory timestamps = new uint256[](4);
        timestamps[0] = initialTimestamp + 1 days;
        timestamps[1] = initialTimestamp + 2 days;
        timestamps[2] = initialTimestamp + 3 days;
        timestamps[3] = initialTimestamp + 4 days;
        vault = ChunkedVestingVault(
            factory.createVault(
                address(token),
                address(beneficiary),
                address(0),
                makeArray(100, 100, 100),
                timestamps
            )
        );
    }

    function testFailClaimUnauthorized(uint256 timestamp) public {
        vm.warp(timestamp);
        MockBeneficiary fakeBeneficiary = new MockBeneficiary();
        fakeBeneficiary.claim(vault);
    }

    function testFailClaimZero() public {
        assertClaimAmount(0);
    }

    function testClawbackAll() public {
        assertEq(clawbackVault.vested(), 0);
        assertEq(clawbackVault.unvested(), 300);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(clawbackVault)), 300);
        clawbackVault.clawback();
        assertGt(clawbackVault.clawbackTimestamp(), 0);
        assertEq(clawbackVault.vested(), 0);
        assertEq(clawbackVault.unvested(), 0);
        assertEq(token.balanceOf(address(clawbackVault)), 0);
        assertEq(token.balanceOf(address(this)), 300);
        vm.warp(initialTimestamp + 3 days);
        assertEq(clawbackVault.vested(), 0);
        assertEq(clawbackVault.unvested(), 0);
    }

    function testClawbackNone() public {
        vm.warp(initialTimestamp + 3 days);

        assertEq(clawbackVault.vested(), 300);
        assertEq(clawbackVault.unvested(), 0);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(clawbackVault)), 300);
        clawbackVault.clawback();
        assertGt(clawbackVault.clawbackTimestamp(), 0);
        assertEq(clawbackVault.vested(), 300);
        assertEq(clawbackVault.unvested(), 0);
        assertEq(token.balanceOf(address(clawbackVault)), 300);
        assertEq(token.balanceOf(address(this)), 0);

        uint256 initialBalance = token.balanceOf(address(beneficiary));
        beneficiary.claim(clawbackVault);
        assertEq(initialBalance + 300, token.balanceOf(address(beneficiary)));
        assertEq(token.balanceOf(address(clawbackVault)), 0);
    }

    function testClawbackPartial() public {
        vm.warp(initialTimestamp + 1 days);

        assertEq(clawbackVault.vested(), 100);
        assertEq(clawbackVault.unvested(), 200);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(clawbackVault)), 300);
        clawbackVault.clawback();
        assertGt(clawbackVault.clawbackTimestamp(), 0);
        assertEq(clawbackVault.vested(), 100);
        assertEq(clawbackVault.unvested(), 0);
        assertEq(token.balanceOf(address(clawbackVault)), 100);
        assertEq(token.balanceOf(address(this)), 200);

        vm.warp(initialTimestamp + 3 days);

        uint256 initialBalance = token.balanceOf(address(beneficiary));
        beneficiary.claim(clawbackVault);
        assertEq(initialBalance + 100, token.balanceOf(address(beneficiary)));
        assertEq(token.balanceOf(address(clawbackVault)), 0);
    }

    function testClawbackAdmin() public {
        assertEq(vault.owner(), address(0));
        assertEq(clawbackVault.owner(), address(this));
        clawbackVault.transferOwnership(address(0));
        assertEq(clawbackVault.owner(), address(0));
    }

    function testRevertClawback() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vault.clawback();
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

    function assertUintArrayEq(uint256[] memory a, uint256[] memory b)
        internal
    {
        require(a.length == b.length, "LENGTH_MISMATCH");

        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }
}
