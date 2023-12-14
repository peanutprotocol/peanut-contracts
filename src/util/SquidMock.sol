// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Suuuuper dumb squid mock.
// We call squid router with just a blob of calldata and don't care about the details
// (e.g. which function was called, with what particular arguments, etc.),
// so here we just have a simple function that we encode into a calldata blob in tests.
contract SquidMock {
    using SafeERC20 for IERC20;

    event SquidMockBridged();

    function superPowerfulBridge(address bridgedToken, uint256 bridgedAmount) public payable {
        if (bridgedToken == address(0)) {
            require(msg.value == bridgedAmount, "msg.value DOESNT MATCH bridgedAmount");
        } else {
            IERC20(bridgedToken).safeTransferFrom(msg.sender, address(this), bridgedAmount);
        }

        emit SquidMockBridged();
    }
}