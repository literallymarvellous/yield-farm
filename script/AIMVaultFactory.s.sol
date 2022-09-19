// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "../src/AIMVaultFactory.sol";
import "../src/AIMVault.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

contract MyScript is Script {
    address owner = 0xcF4AbEE5eCe1979C139A3837a7aCE130c782863e;
    ERC20 public underlying = ERC20(0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C);
    address public cToken = 0xCEC4a43eBB02f9B80916F1c718338169d6d5C1F0;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        AIMVaultFactory vaultFactory = new AIMVaultFactory(owner);
        vaultFactory.deployVault(underlying, cToken, owner);

        vm.stopBroadcast();
    }
}
