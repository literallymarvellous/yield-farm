// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import "../src/AIMVaultFactory.sol";
import {AIMVault} from "../src/AIMVault.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {CErc20} from "../src/interface/CErcInterface.sol";
import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";

contract VaultFactoryTest is Test {
    address public DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    // compound
    address public CDAI = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;

    AIMVaultFactory vaultFactory;

    ERC20 public underlying;
    CErc20 public cToken;
    address owner;

    function setUp() public {
        owner = vm.addr(1);
        vaultFactory = new AIMVaultFactory(address(this));
        // underlying = ERC20(DAI);
        underlying = new MockERC20("Mock Token", "TKN", 18);
        cToken = CErc20(CDAI);
        // AIMVault vault2 = new AIMVault(underlying, CDAI);
    }

    function testDeployVault() public {
        AIMVault vault = vaultFactory.deployVault(underlying, CDAI);

        assertTrue(vaultFactory.isVaultDeployed(vault));
        assertEq(
            address(vaultFactory.getVaultFromUnderlying(underlying, CDAI)),
            address(vault)
        );
        assertEq(address(vault.UNDERLYING()), address(underlying));
    }

    function testFailNoDuplicateVaults() public {
        vm.expectRevert();
        vaultFactory.deployVault(underlying, CDAI);
        vm.expectRevert();
        vaultFactory.deployVault(underlying, CDAI);
    }

    function testIsVaultDeployed() public {
        AIMVault vault = vaultFactory.deployVault(underlying, CDAI);
        assertTrue(vaultFactory.isVaultDeployed(vault));
    }
}
