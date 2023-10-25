// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/V5/PeanutV5.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Create new peanut contract (with broadcast enabled this will send the tx to mempool)
        PeanutV5 peanutV5 = new PeanutV5();

        vm.stopBroadcast();

        // do something for no unused variable warning (log contract address)
        console.log("contract address: %s", address(peanutV5));
    }
}
