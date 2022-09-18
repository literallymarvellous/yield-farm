// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import "../src/AIMVaultFactory.sol";
import {AIMVault} from "../src/AIMVault.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {CErc20} from "../src/interface/CErcInterface.sol";
import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";

contract VaultFactoryTest is Test {
    // compound
    address public CDAI = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;

    AIMVaultFactory vaultFactory;

    ERC20 public underlying;
    CErc20 public cToken;
    address owner;

    function setUp() public {
        vaultFactory = new AIMVaultFactory(address(this));
        underlying = new MockERC20("Mock Token", "TKN", 18);
        cToken = CErc20(CDAI);
    }

    function testDeployVault() public {
        AIMVault vault = vaultFactory.deployVault(
            underlying,
            CDAI,
            address(this)
        );

        assertTrue(vaultFactory.isVaultDeployed(vault));
        assertEq(
            address(
                vaultFactory.getVaultFromUnderlying(
                    underlying,
                    CDAI,
                    address(this)
                )
            ),
            address(vault)
        );
        assertEq(address(vault.UNDERLYING()), address(underlying));
    }

    function testFailNotOwnerDeployedVault() public {
        address alice = vm.addr(1);
        vm.prank(alice);
        vm.expectRevert();
        vaultFactory.deployVault(underlying, CDAI, address(this));
    }

    function testFailNoDuplicateVaults() public {
        vm.expectRevert();
        vaultFactory.deployVault(underlying, CDAI, address(this));
        vm.expectRevert();
        vaultFactory.deployVault(underlying, CDAI, address(this));
    }

    function testIsVaultDeployed() public {
        AIMVault vault = vaultFactory.deployVault(
            underlying,
            CDAI,
            address(this)
        );
        assertTrue(vaultFactory.isVaultDeployed(vault));
        assertTrue(vaultFactory.vaults(underlying) == vault);
    }
}
