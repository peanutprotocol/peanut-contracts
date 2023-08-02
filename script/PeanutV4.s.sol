// SPDX-License-Identifier: UNLICENSED
// deploy Peanut Contract
// forge script script/PeanutV4.s.sol:DeployScript --fork-url http://localhost:8545 --broadcast
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/V4/PeanutV4.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Create new peanut contract (with broadcast enabled this will send the tx to mempool)
        PeanutV4 peanutV4 = new PeanutV4();

        vm.stopBroadcast();

        // do something for no unused variable warning
        peanutV4;
    }
}
