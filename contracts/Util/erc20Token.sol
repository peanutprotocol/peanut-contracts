// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PeanutERC20 is ERC20 {

    constructor() ERC20("NUT", "PeanutToken") {
        _mint(msg.sender, 10 ** 18 * 1000000);
    }
}
