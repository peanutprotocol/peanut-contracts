// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP3009Implementation} from "./EIP3009Implementation.sol";

// A simple ERC20 mock that also implements EIP-3009 and allows gasless transfers
contract ERC20Mock is EIP3009Implementation {
    constructor() ERC20("ERC20Mock", "20MOCK") {
        this;
    }

    // mint function mints tokens to the specified address
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
