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
    address public cWBTCG = 0x6CE27497A64fFFb5517AA4aeE908b1E7EB63B9fF;
    address public WBTCG = 0xC04B0d3107736C32e19F1c62b2aF67BE61d63a05;

    // address public DAIG = 0x2899a03ffDab5C90BADc5920b4f53B0884EB13cC;
    address public DAIG = 0xdc31Ee1784292379Fbb2964b3B9C4124D8F89C60;
    address public cDAIG = 0x0545a8eaF7ff6bB6F708CbB544EA55DBc2ad7b2a;

    address public USDCG = 0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C;
    address public cUSDCG = 0xCEC4a43eBB02f9B80916F1c718338169d6d5C1F0;

    AIMVaultFactory vaultFactory;
    AIMVault vault;

    ERC20 public underlying;
    CErc20 public cToken;
    address owner;
    address public alice;
    address public bob;

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

        console2.log("bob balance", underlying.balanceOf(bob));

        vm.prank(alice);
        underlying.approve(address(vault), aliceDeposit);

        assertEq(underlying.allowance(alice, address(vault)), aliceDeposit);

        vm.prank(bob);
        underlying.approve(address(vault), bobDeposit);

        assertEq(underlying.allowance(bob, address(vault)), bobDeposit);

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

        uint256 newBlock = block.number + 8000;

        // 3. Simulating yield from compound                  |
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

        // subtracting 1 to reflect compound strategy cost
        // bob's and alice's assets should match total asset
        assertEq(aliceAssets + bobAssets, vault.totalAssets() - 1);

        // // 4. Alice deposits 2000 tokens (mints 1333 shares)
        // hevm.prank(alice);
        // vault.deposit(2000, alice);

        // assertEq(vault.totalSupply(), 7333);
        // assertEq(vault.balanceOf(alice), 3333);
        // assertEq(vault.convertToAssets(vault.balanceOf(alice)), 4999);
        // assertEq(vault.balanceOf(bob), 4000);
        // assertEq(vault.convertToAssets(vault.balanceOf(bob)), 6000);

        // // 5. Bob mints 2000 shares (costs 3001 assets)
        // // NOTE: Bob's assets spent got rounded up
        // // NOTE: Alices's vault assets got rounded up
        // hevm.prank(bob);
        // vault.mint(2000, bob);

        // assertEq(vault.totalSupply(), 9333);
        // assertEq(vault.balanceOf(alice), 3333);
        // assertEq(vault.convertToAssets(vault.balanceOf(alice)), 5000);
        // assertEq(vault.balanceOf(bob), 6000);
        // assertEq(vault.convertToAssets(vault.balanceOf(bob)), 9000);

        // // Sanity checks:
        // // Alice and bob should have spent all their tokens now
        // assertEq(underlying.balanceOf(alice), 0);
        // assertEq(underlying.balanceOf(bob), 0);
        // // Assets in vault: 4k (alice) + 7k (bob) + 3k (yield) + 1 (round up)
        // assertEq(vault.totalAssets(), 14001);

        // // 6. Vault mutates by +3000 tokens
        // // NOTE: Vault holds 17001 tokens, but sum of assetsOf() is 17000.
        // underlying.mint(address(vault), mutationUnderlyingAmount);
        // assertEq(vault.totalAssets(), 17001);
        // assertEq(vault.convertToAssets(vault.balanceOf(alice)), 6071);
        // assertEq(vault.convertToAssets(vault.balanceOf(bob)), 10929);

        // // 7. Alice redeem 1333 shares (2428 assets)
        // hevm.prank(alice);
        // vault.redeem(1333, alice, alice);

        // assertEq(underlying.balanceOf(alice), 2428);
        // assertEq(vault.totalSupply(), 8000);
        // assertEq(vault.totalAssets(), 14573);
        // assertEq(vault.balanceOf(alice), 2000);
        // assertEq(vault.convertToAssets(vault.balanceOf(alice)), 3643);
        // assertEq(vault.balanceOf(bob), 6000);
        // assertEq(vault.convertToAssets(vault.balanceOf(bob)), 10929);

        // // 8. Bob withdraws 2929 assets (1608 shares)
        // hevm.prank(bob);
        // vault.withdraw(2929, bob, bob);

        // assertEq(underlying.balanceOf(bob), 2929);
        // assertEq(vault.totalSupply(), 6392);
        // assertEq(vault.totalAssets(), 11644);
        // assertEq(vault.balanceOf(alice), 2000);
        // assertEq(vault.convertToAssets(vault.balanceOf(alice)), 3643);
        // assertEq(vault.balanceOf(bob), 4392);
        // assertEq(vault.convertToAssets(vault.balanceOf(bob)), 8000);

        // // 9. Alice withdraws 3643 assets (2000 shares)
        // // NOTE: Bob's assets have been rounded back up
        // hevm.prank(alice);
        // vault.withdraw(3643, alice, alice);

        // assertEq(underlying.balanceOf(alice), 6071);
        // assertEq(vault.totalSupply(), 4392);
        // assertEq(vault.totalAssets(), 8001);
        // assertEq(vault.balanceOf(alice), 0);
        // assertEq(vault.convertToAssets(vault.balanceOf(alice)), 0);
        // assertEq(vault.balanceOf(bob), 4392);
        // assertEq(vault.convertToAssets(vault.balanceOf(bob)), 8001);

        // // 10. Bob redeem 4392 shares (8001 tokens)
        // hevm.prank(bob);
        // vault.redeem(4392, bob, bob);
        // assertEq(underlying.balanceOf(bob), 10930);
        // assertEq(vault.totalSupply(), 0);
        // assertEq(vault.totalAssets(), 0);
        // assertEq(vault.balanceOf(alice), 0);
        // assertEq(vault.convertToAssets(vault.balanceOf(alice)), 0);
        // assertEq(vault.balanceOf(bob), 0);
        // assertEq(vault.convertToAssets(vault.balanceOf(bob)), 0);

        // // Sanity check
        // assertEq(underlying.balanceOf(address(vault)), 0);
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
}
