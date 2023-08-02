// SPDX-License-Identifier: UNLICENSED
// deploy Peanut Contract
// forge script script/PeanutV4.s.sol:DeployScript --fork-url http://localhost:8545 --broadcast
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "../src/archive/V3/PeanutV3.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Create new peanut contract (with broadcast enabled this will send the tx to mempool)
        PeanutV3 peanutV3 = new PeanutV3();

        vm.stopBroadcast();
    }
}
