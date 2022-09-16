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

    address public DAIG = 0x2899a03ffDab5C90BADc5920b4f53B0884EB13cC;
    address public cDAIG = 0x0545a8eaF7ff6bB6F708CbB544EA55DBc2ad7b2a;

    AIMVaultFactory vaultFactory;
    AIMVault vault;

    ERC20 public underlying;
    CErc20 public cToken;
    address owner;

    function setUp() public {
        vaultFactory = new AIMVaultFactory(address(this));
        cToken = CErc20(cDAIG);
        underlying = ERC20(DAIG);
        vault = vaultFactory.deployVault(underlying, cDAIG);
    }

    function testFactoryDeploy() public {
        assertTrue(vaultFactory.isVaultDeployed(vault));
    }

    function testMetadata() public {
        assertEq(vault.name(), "Aim Dai Stablecoin Vault");
        assertEq(vault.symbol(), "avDAI");
        assertEq(vault.decimals(), 18);
    }

    function testSingleDepositWithdraw() public {}
}
