// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

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
    address public me;

    function setUp() public {
        vaultFactory = new AIMVaultFactory(address(this));
        // cToken = CErc20(cDAIG);
        // underlying = ERC20(DAIG);
        cToken = CErc20(cUSDCG);
        underlying = ERC20(USDCG);
        vault = vaultFactory.deployVault(underlying, cUSDCG);

        me = vm.addr(
            0xe2d0e9561848b56f89253fa63e244fcb825e0520f7486119e06e1bb9549dd10c
        );
        console2.log("me addr", me);
        console2.log("underlying addr", address(underlying));
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
        vm.startPrank(me);
        console2.log(
            "usdc balance:",
            underlying.balanceOf(0x622F73efA07Efd4814Aa9695a1EaDCF8644b1B1F)
        );
        underlying.approve(address(vault), deposit);
        uint256 shares = vault.deposit(deposit, me);
        console2.log("shares", shares);
        assert(shares > 0);
        console2.log(
            "underlying balance vault:",
            underlying.balanceOf(address(vault))
        );
    }
}
