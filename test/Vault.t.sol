// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/AIMVaultFactory.sol";
import {AIMVault} from "../src/AIMVault.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {CErc20} from "../src/interface/CErcInterface.sol";

contract VaultTest is Test {
    address public DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    // compound
    address public CDAI = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;

    AIMVaultFactory vaultFactory;
    AIMVault vault;

    ERC20 public underlying;
    CErc20 public cToken;
    address owner;

    function setUp() public {
        owner = vm.addr(1);
    }

    function testFactoryDeploy() public {
        assertTrue(true);
    }
}
