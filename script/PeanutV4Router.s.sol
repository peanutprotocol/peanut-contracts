// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/V4/PeanutRouter.sol";
import "./DeploymentGlobals.sol";

contract DeployScript is Script, DeploymentGlobals {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Create new peanut contract (with broadcast enabled this will send the tx to mempool)
        // Achtung! The deployer will become the first owner of the contract
        // and will be the only party able to withdraw fees.
        PeanutV4Router peanutV4Router = new PeanutV4Router(squidAddress);

        vm.stopBroadcast();

        // do something for no unused variable warning (log contract address)
        console.log("contract address: %s", address(peanutV4Router));
    }
}
