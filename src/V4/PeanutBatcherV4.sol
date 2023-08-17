// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IPeanut {
    function makeDeposit(
        address _tokenAddress,
        uint8 _contractType,
        uint256 _amount,
        uint256 _tokenId,
        address _pubKey20
    ) external payable returns (uint256);
}

contract PeanutBatcher is ReentrancyGuard {
    IPeanut public peanut;

    constructor(address _peanutAddress) {
        require(_peanutAddress != address(0), "Invalid address");
        peanut = IPeanut(_peanutAddress);
    }

    function batchMakeDepositEther(uint256[] calldata _amounts, address[] calldata _pubKeys20)
        external
        payable
        nonReentrant
        returns (uint256[] memory)
    {
        require(_amounts.length == _pubKeys20.length, "PARAMETERS LENGTH MISMATCH");

        uint256[] memory depositIndexes = new uint256[](_amounts.length);
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];

            depositIndexes[i] = peanut.makeDeposit(address(0), 0, _amounts[i], 0, _pubKeys20[i]);
        }

        require(msg.value == totalAmount, "INVALID TOTAL ETHER SENT");

        return depositIndexes;
    }

    function batchMakeDepositERC20(address _tokenAddress, uint256[] calldata _amounts, address[] calldata _pubKeys20)
        external
        nonReentrant
        returns (uint256[] memory)
    {
        require(_amounts.length == _pubKeys20.length, "PARAMETERS LENGTH MISMATCH");

        uint256[] memory depositIndexes = new uint256[](_amounts.length);

        for (uint256 i = 0; i < _amounts.length; i++) {
            depositIndexes[i] = peanut.makeDeposit(_tokenAddress, 1, _amounts[i], 0, _pubKeys20[i]);
        }

        return depositIndexes;
    }

    function batchMakeDepositERC721(address _tokenAddress, uint256[] calldata _tokenIds, address[] calldata _pubKeys20)
        external
        nonReentrant
        returns (uint256[] memory)
    {
        require(_tokenIds.length == _pubKeys20.length, "PARAMETERS LENGTH MISMATCH");

        uint256[] memory depositIndexes = new uint256[](_tokenIds.length);

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            depositIndexes[i] = peanut.makeDeposit(_tokenAddress, 2, 0, _tokenIds[i], _pubKeys20[i]);
        }

        return depositIndexes;
    }

    function batchMakeDepositERC1155(
        address _tokenAddress,
        uint256[] calldata _amounts,
        uint256[] calldata _tokenIds,
        address[] calldata _pubKeys20
    ) external nonReentrant returns (uint256[] memory) {
        require(
            _amounts.length == _pubKeys20.length && _tokenIds.length == _pubKeys20.length, "PARAMETERS LENGTH MISMATCH"
        );

        uint256[] memory depositIndexes = new uint256[](_amounts.length);

        for (uint256 i = 0; i < _amounts.length; i++) {
            depositIndexes[i] = peanut.makeDeposit(_tokenAddress, 3, _amounts[i], _tokenIds[i], _pubKeys20[i]);
        }

        return depositIndexes;
    }
}
