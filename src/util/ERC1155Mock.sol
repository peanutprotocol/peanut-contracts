// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract ERC1155Mock is ERC1155 {
    constructor() ERC1155("https://example.com/{id}.json") {
        this;
    }

    // mint function mints tokens to the specified address (respecting the ERC1155 standard)
    function mint(address account, uint256 id, uint256 amount, bytes memory data) external {
        _mint(account, id, amount, data);
    }
}
