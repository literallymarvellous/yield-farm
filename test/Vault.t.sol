// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../src/AIMVaultFactory.sol";
import {AIMVault} from "../src/AIMVault.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {CErc20} from "../src/interface/CErcInterface.sol";
import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC4626} from "@solmate/mixins/ERC4626.sol";

contract VaultTest is Test {
    // georli testnet
    address public USDCG = 0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C;
    address public cUSDCG = 0xCEC4a43eBB02f9B80916F1c718338169d6d5C1F0;

    AIMVaultFactory vaultFactory;
    AIMVault vault;

    ERC20 public underlying;
    CErc20 public cToken;
    address owner;
    address public alice;
    address public bob;
    address public john;

    uint256 georliFork;
    string URL = vm.envString("GOERLI_RPC_URL");

    function setUp() public {
        georliFork = vm.createSelectFork(URL, 7605023);

        vaultFactory = new AIMVaultFactory(address(this));

        cToken = CErc20(cUSDCG);
        underlying = ERC20(USDCG);
        vault = vaultFactory.deployVault(underlying, cUSDCG, address(this));
        vm.makePersistent(address(vault));

        alice = vm.addr(
            0xe2d0e9561848b56f89253fa63e244fcb825e0520f7486119e06e1bb9549dd10c
        );
        bob = vm.addr(
            0x4b0b2d904f0eb3d053f5b04169031c42072df7ebde70cb4433bb8cb9a1d45ecf
        );

        john = vm.addr(
            0x905cd7bf44b257facf07805794510d54201a2ec66427a5f5645050e8abc72fd5
        );

        vm.label(address(vaultFactory), "vaultFactory");
        vm.label(address(vault), "vault");
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(address(this), "test");
        vm.label(address(underlying), "underlying");
        vm.label(address(cToken), "cToken");
    }

    function testFactoryDeploy() public {
        assertTrue(vaultFactory.isVaultDeployed(vault));
    }

    function testMetadata() public {
        assertEq(vault.name(), "Aim USD Coin Vault");
        assertEq(vault.symbol(), "avUSDC");
        assertEq(vault.decimals(), 6);
    }

    function testSingleDepositWithdraw() public {
        uint256 deposit = 10 * 10**6;
        uint256 aliceUnderlyingAmount = deposit;

        vm.prank(alice);
        underlying.approve(address(vault), deposit);
        assertEq(underlying.allowance(alice, address(vault)), deposit);

        uint256 alicePreDepositBal = underlying.balanceOf(alice);

        vm.prank(alice);
        uint256 aliceShares = vault.deposit(deposit, alice);
        assert(aliceShares > 0);

        // Expect exchange rate to be 1:1 on initial deposit.
        assertEq(aliceUnderlyingAmount, aliceShares);
        assertEq(vault.previewWithdraw(aliceShares), aliceUnderlyingAmount);
        assertEq(vault.previewDeposit(aliceUnderlyingAmount), aliceShares);
        assertEq(vault.totalSupply(), aliceShares);
        assertEq(vault.totalAssets(), aliceUnderlyingAmount);
        assertEq(vault.balanceOf(alice), aliceShares);
        assertEq(
            vault.convertToAssets(vault.balanceOf(alice)),
            aliceUnderlyingAmount
        );
        assertEq(
            underlying.balanceOf(alice),
            alicePreDepositBal - aliceUnderlyingAmount
        );

        vm.prank(alice);
        vault.withdraw(aliceUnderlyingAmount, alice, alice);

        assertEq(vault.totalAssets(), 0);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 0);
        assertEq(underlying.balanceOf(alice), alicePreDepositBal);
    }

    function testSingleMintRedeem() public {
        uint256 deposit = 10 * 10**6;
        uint256 aliceShareAmount = deposit;

        vm.prank(alice);
        underlying.approve(address(vault), deposit);
        assertEq(underlying.allowance(alice, address(vault)), deposit);

        uint256 alicePreDepositBal = underlying.balanceOf(alice);

        vm.prank(alice);
        uint256 aliceUnderlyingAmount = vault.mint(deposit, alice);
        assert(aliceUnderlyingAmount > 0);

        // Expect exchange rate to be 1:1 on initial deposit.
        assertEq(aliceShareAmount, aliceUnderlyingAmount);
        assertEq(
            vault.previewWithdraw(aliceShareAmount),
            aliceUnderlyingAmount
        );
        assertEq(vault.previewDeposit(aliceUnderlyingAmount), aliceShareAmount);
        assertEq(vault.totalSupply(), aliceShareAmount);
        assertEq(vault.totalAssets(), aliceUnderlyingAmount);
        assertEq(vault.balanceOf(alice), aliceShareAmount);
        assertEq(
            vault.convertToAssets(vault.balanceOf(alice)),
            aliceUnderlyingAmount
        );
        assertEq(
            underlying.balanceOf(alice),
            alicePreDepositBal - aliceUnderlyingAmount
        );

        vm.prank(alice);
        vault.redeem(aliceShareAmount, alice, alice);

        assertEq(vault.totalAssets(), 0);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 0);
    }

    function testMultipleMintDepositRedeemWithdraw() public {
        uint256 aliceDeposit = 20 * 10e6;
        uint256 bobDeposit = 40 * 10e6;

        vm.prank(alice);
        underlying.transfer(bob, 1000000000);
        vm.prank(alice);
        underlying.transfer(john, 1000000000);

        vm.prank(alice);
        underlying.approve(address(vault), 1000000000);

        assertEq(underlying.allowance(alice, address(vault)), 1000000000);

        vm.prank(bob);
        underlying.approve(address(vault), 1000000000);

        vm.prank(john);
        underlying.approve(address(vault), 1000000000);

        assertEq(underlying.allowance(bob, address(vault)), 1000000000);

        // 1. Alice mints 200000000 shares (costs 200000000 tokens)
        vm.prank(alice);
        uint256 aliceUnderlyingAmount = vault.mint(aliceDeposit, alice);

        uint256 aliceShareAmount = vault.previewDeposit(aliceUnderlyingAmount);

        // Expect to have received the requested mint amount.
        assertEq(aliceShareAmount, aliceDeposit);
        assertEq(vault.balanceOf(alice), aliceShareAmount);
        assertEq(
            vault.convertToAssets(vault.balanceOf(alice)),
            aliceUnderlyingAmount
        );
        assertEq(
            vault.convertToShares(aliceUnderlyingAmount),
            vault.balanceOf(alice)
        );

        // Expect a 1:1 ratio before mutation.
        assertEq(aliceUnderlyingAmount, aliceDeposit);

        // Sanity check.
        assertEq(vault.totalSupply(), aliceShareAmount);
        assertEq(vault.totalAssets(), aliceUnderlyingAmount);

        // 2. Bob deposits 400000000 tokens (mints 400000000 shares)
        vm.prank(bob);
        uint256 bobShareAmount = vault.deposit(bobDeposit, bob);
        uint256 bobUnderlyingAmount = vault.previewWithdraw(bobShareAmount);

        // Expect to have received the requested underlying amount.
        assertEq(bobUnderlyingAmount, bobDeposit);
        assertEq(vault.balanceOf(bob), bobShareAmount);
        assertEq(
            vault.convertToAssets(vault.balanceOf(bob)),
            bobUnderlyingAmount
        );
        assertEq(
            vault.convertToShares(bobUnderlyingAmount),
            vault.balanceOf(bob)
        );

        // Expect a 1:1 ratio before mutation.
        assertEq(bobShareAmount, bobUnderlyingAmount);

        // Sanity check.
        uint256 preYeildShareBal = aliceShareAmount + bobShareAmount;
        uint256 preYeildBal = aliceUnderlyingAmount + bobUnderlyingAmount;
        assertEq(vault.totalSupply(), preYeildShareBal);
        assertEq(vault.totalAssets(), preYeildBal);
        assertEq(vault.totalSupply(), 600000000);
        assertEq(vault.totalAssets(), 600000000);

        // 3. Simulating yield from compound
        uint256 newBlock = block.number + 8000;
        vm.roll(newBlock);

        // Share total and count for bob and alice stay the same
        assertEq(vault.totalSupply(), preYeildShareBal);
        assertEq(vault.balanceOf(alice), aliceShareAmount);
        assertEq(vault.balanceOf(bob), bobShareAmount);

        // update strategy holfing to reflect yield in contract;
        // this happens automatically when redem or withdraw is called
        vault.updateTotalStrategyHoldings();

        uint256 postYeildBal = vault.totalAssets();
        assertGt(postYeildBal, preYeildBal);

        uint256 aliceAssets = vault.convertToAssets(aliceShareAmount);
        uint256 bobAssets = vault.convertToAssets(bobShareAmount);

        // delta is included to reflect compound strategy deposit cost
        // bob's and alice's assets should match total asset
        assertApproxEqAbs(aliceAssets + bobAssets, vault.totalAssets(), 2);

        // 4. Another round of mint from alice, bob and now John
        vm.prank(alice);
        vault.deposit(20000000, alice);

        vm.prank(bob);
        vault.mint(20000000, bob);
        // bobShareAmount = vault.convertToShares(bobUnderlyingAmount);

        vm.prank(john);
        vault.deposit(70000000, john);

        // Sanity check.
        // vault balance of address == shares minted
        aliceShareAmount = vault.balanceOf(alice);
        bobShareAmount = vault.balanceOf(bob);
        uint256 johnShareAmount = vault.balanceOf(john);
        preYeildShareBal = aliceShareAmount + bobShareAmount + johnShareAmount;

        aliceUnderlyingAmount = vault.convertToAssets(aliceShareAmount);
        bobUnderlyingAmount = vault.convertToAssets(bobShareAmount);
        uint256 johnUnderlyingAmount = vault.convertToAssets(johnShareAmount);
        preYeildBal =
            aliceUnderlyingAmount +
            bobUnderlyingAmount +
            johnUnderlyingAmount;

        assertEq(vault.totalSupply(), preYeildShareBal);
        assertApproxEqAbs(vault.totalAssets(), preYeildBal, 2);

        // 5. Simulating another round of yield from compound
        newBlock = block.number + 2000;
        vm.roll(newBlock);

        // Share total and count for bob and alice stay the same
        assertEq(vault.totalSupply(), preYeildShareBal);
        assertEq(vault.balanceOf(alice), aliceShareAmount);
        assertEq(vault.balanceOf(bob), bobShareAmount);
        assertEq(vault.balanceOf(john), johnShareAmount);

        vault.updateTotalStrategyHoldings();

        postYeildBal = vault.totalAssets();
        assertGt(postYeildBal, preYeildBal);

        aliceAssets = vault.convertToAssets(aliceShareAmount);
        bobAssets = vault.convertToAssets(bobShareAmount);
        uint256 johnAssets = vault.convertToAssets(johnShareAmount);

        assertApproxEqAbs(
            aliceAssets + bobAssets + johnAssets,
            vault.totalAssets(),
            2
        );

        // 8. Bob withdraws 30000000 assets
        vm.prank(bob);
        vault.withdraw(30000000, bob, bob);

        bobShareAmount = vault.balanceOf(bob);
        assertEq(bobAssets - 30000000, vault.convertToAssets(bobShareAmount));

        // 9. Alice redeems half her shares
        vm.prank(alice);
        uint256 redeemShares = aliceShareAmount / 2;
        vault.redeem(redeemShares, alice, alice);

        assertEq(vault.balanceOf(alice), redeemShares);

        // 10. John redeem all shares
        uint256 johnUnderlyingPreRedeem = underlying.balanceOf(john);

        vm.prank(john);
        vault.redeem(johnShareAmount, john, john);

        uint256 johnUnderlyingPostRedeem = underlying.balanceOf(john);
        assertEq(vault.balanceOf(john), 0);

        // current underlying balance >= previous balance before reddem + vault deposit
        assertGe(johnUnderlyingPostRedeem, johnUnderlyingPreRedeem + 70000000);

        // Sanity check
        // Remainig shares == ALices's shares + Bob's shares
        assertEq(
            vault.balanceOf(alice) + vault.balanceOf(bob),
            vault.totalSupply()
        );

        aliceAssets = vault.convertToAssets(vault.balanceOf(alice));
        bobAssets = vault.convertToAssets(vault.balanceOf(bob));
        assertApproxEqAbs(aliceAssets + bobAssets, vault.totalAssets(), 2);

        // Bob redeems remaining shares
        bobShareAmount = vault.balanceOf(bob);
        vm.prank(bob);
        vault.redeem(bobShareAmount, bob, bob);
        assertEq(vault.balanceOf(bob), 0);

        // Alice withdraws remaining assets
        vm.prank(alice);
        vault.withdraw(aliceAssets, alice, alice);
        assertEq(vault.balanceOf(alice), 0);

        // Vault should be empty
        assertEq(vault.totalSupply(), 0);
        assertApproxEqAbs(vault.totalAssets(), 0, 1);
    }

    function testFailDepositWithNotEnoughApproval() public {
        vm.startPrank(alice);
        underlying.approve(address(vault), 1e6);
        assertEq(underlying.allowance(address(alice), address(vault)), 1e6);

        vault.deposit(2e6, address(this));
    }

    function testFailWithdrawWithNotEnoughUnderlyingAmount() public {
        vm.startPrank(alice);
        underlying.approve(address(vault), 1e6);

        vault.deposit(1e6, address(this));

        vault.withdraw(2e6, address(this), address(this));
    }

    function testFailRedeemWithNotEnoughShareAmount() public {
        vm.startPrank(alice);
        underlying.approve(address(vault), 1e6);

        vault.deposit(1e6, address(this));

        vault.redeem(2e6, address(this), address(this));
    }

    function testFailWithdrawWithNoUnderlyingAmount() public {
        vm.startPrank(alice);
        vault.withdraw(1e6, address(this), address(this));
    }

    function testFailRedeemWithNoShareAmount() public {
        vm.startPrank(alice);
        vault.redeem(1e6, address(this), address(this));
    }

    function testFailDepositWithNoApproval() public {
        vm.startPrank(alice);
        vault.deposit(1e6, address(this));
    }

    function testFailMintWithNoApproval() public {
        vm.startPrank(alice);
        vault.mint(1e6, address(this));
    }

    function testFailDepositZero() public {
        vm.startPrank(alice);
        vault.deposit(0, address(this));
    }

    function testMintZero() public {
        vm.startPrank(alice);
        vault.mint(0, address(this));

        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);
    }

    function testFailRedeemZero() public {
        vm.startPrank(alice);
        vault.redeem(0, address(this), address(this));
    }

    function testWithdrawZero() public {
        vm.startPrank(alice);
        vault.withdraw(0, address(this), address(this));

        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);
    }

    function testCannotUpdateTotalStrategyHoldingsIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert("UNAUTHORIZED");
        vault.updateTotalStrategyHoldings();
    }
}
