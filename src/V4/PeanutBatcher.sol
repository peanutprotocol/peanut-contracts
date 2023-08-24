// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IPeanut {
    function makeDeposit(
        address _tokenAddress,
        uint8 _contractType,
        uint256 _amount,
        uint256 _tokenId,
        address _pubKey20
    ) external payable returns (uint256);
}

contract PeanutBatcher {
    using SafeERC20 for IERC20;
    IPeanut public peanut;

    // arbitrary but samesy deposit. Assumes all deposits are the same. Gas efficient
    function batchMakeDeposit(
        address _peanutAddress,
        address _tokenAddress,
        uint8 _contractType,
        uint256 _amount,
        uint256 _tokenId,
        address[] calldata _pubKeys20
    ) external payable returns (uint256[] memory) {
        peanut = IPeanut(_peanutAddress);

        uint256 totalAmount = _amount * _pubKeys20.length;

        // Transfer tokens to this contract & approve them for the peanut contract.
        if (_contractType == 0) {
            require(msg.value == totalAmount, "INVALID TOTAL ETHER SENT");
        } else if (_contractType == 1) {
            IERC20(_tokenAddress).safeTransferFrom(msg.sender, address(this), totalAmount);
            IERC20(_tokenAddress).safeApprove(address(peanut), type(uint256).max);
        } else if (_contractType == 2) {
            IERC721(_tokenAddress).setApprovalForAll(address(peanut), true);
        } else if (_contractType == 3) {
            IERC1155(_tokenAddress).safeTransferFrom(msg.sender, address(this), _tokenId, totalAmount, "");
            IERC1155(_tokenAddress).setApprovalForAll(address(peanut), true);
        }

        uint256[] memory depositIndexes = new uint256[](_pubKeys20.length);

        for (uint256 i = 0; i < _pubKeys20.length; i++) {
            depositIndexes[i] =
                peanut.makeDeposit{value: _amount}(_tokenAddress, _contractType, _amount, _tokenId, _pubKeys20[i]);
        }

        return depositIndexes;
    }

    // Arbitrary but samesy deposit. Assumes all deposits are the same. Gas efficient
    function batchMakeDepositNoReturn(
        address _peanutAddress,
        address _tokenAddress,
        uint8 _contractType,
        uint256 _amount,
        uint256 _tokenId,
        address[] calldata _pubKeys20
    ) external payable {
        peanut = IPeanut(_peanutAddress);

        for (uint256 i = 0; i < _pubKeys20.length; i++) {
            peanut.makeDeposit{value: msg.value}(_tokenAddress, _contractType, _amount, _tokenId, _pubKeys20[i]);
        }
    }

    // arbitrary deposits
    function batchMakeDepositArbitrary(
        address _peanutAddress,
        address[] calldata _tokenAddresses,
        uint8[] calldata _contractTypes,
        uint256[] calldata _amounts,
        uint256[] calldata _tokenIds,
        address[] calldata _pubKeys20
    ) external payable returns (uint256[] memory) {
        require(
            _tokenAddresses.length == _pubKeys20.length && _contractTypes.length == _pubKeys20.length
                && _amounts.length == _pubKeys20.length && _tokenIds.length == _pubKeys20.length,
            "PARAMETERS LENGTH MISMATCH"
        );
        peanut = IPeanut(_peanutAddress);

        uint256[] memory depositIndexes = new uint256[](_amounts.length);

        for (uint256 i = 0; i < _amounts.length; i++) {
            depositIndexes[i] = peanut.makeDeposit{value: msg.value}(
                _tokenAddresses[i], _contractTypes[i], _amounts[i], _tokenIds[i], _pubKeys20[i]
            );
        }

        return depositIndexes;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////
    // Unnecessary for now
    ///////////////////////////////////////////////////////////////////////////////////////////
    // function batchMakeDepositEther(address _peanutAddress, uint256[] calldata _amounts, address[] calldata _pubKeys20)
    //     external
    //     payable
    //     returns (uint256[] memory)
    // {
    //     require(_amounts.length == _pubKeys20.length, "PARAMETERS LENGTH MISMATCH");

    //     peanut = IPeanut(_peanutAddress);

    //     uint256[] memory depositIndexes = new uint256[](_amounts.length);
    //     uint256 totalAmount = 0;

    //     for (uint256 i = 0; i < _amounts.length; i++) {
    //         totalAmount += _amounts[i];

    //         depositIndexes[i] = peanut.makeDeposit(address(0), 0, _amounts[i], 0, _pubKeys20[i]);
    //     }

    //     require(msg.value == totalAmount, "INVALID TOTAL ETHER SENT");

    //     return depositIndexes;
    // }

    // function batchMakeDepositERC20(
    //     address _peanutAddress,
    //     address _tokenAddress,
    //     uint256[] calldata _amounts,
    //     address[] calldata _pubKeys20
    // ) external returns (uint256[] memory) {
    //     require(_amounts.length == _pubKeys20.length, "PARAMETERS LENGTH MISMATCH");
    //     peanut = IPeanut(_peanutAddress);

    //     uint256[] memory depositIndexes = new uint256[](_amounts.length);

    //     for (uint256 i = 0; i < _amounts.length; i++) {
    //         depositIndexes[i] = peanut.makeDeposit(_tokenAddress, 1, _amounts[i], 0, _pubKeys20[i]);
    //     }

    //     return depositIndexes;
    // }

    // function batchMakeDepositERC721(
    //     address _peanutAddress,
    //     address _tokenAddress,
    //     uint256[] calldata _tokenIds,
    //     address[] calldata _pubKeys20
    // ) external returns (uint256[] memory) {
    //     require(_tokenIds.length == _pubKeys20.length, "PARAMETERS LENGTH MISMATCH");

    //     peanut = IPeanut(_peanutAddress);

    //     uint256[] memory depositIndexes = new uint256[](_tokenIds.length);

    //     for (uint256 i = 0; i < _tokenIds.length; i++) {
    //         depositIndexes[i] = peanut.makeDeposit(_tokenAddress, 2, 0, _tokenIds[i], _pubKeys20[i]);
    //     }

    //     return depositIndexes;
    // }

    // function batchMakeDepositERC1155(
    //     address _peanutAddress,
    //     address _tokenAddress,
    //     uint256[] calldata _amounts,
    //     uint256[] calldata _tokenIds,
    //     address[] calldata _pubKeys20
    // ) external returns (uint256[] memory) {
    //     require(
    //         _amounts.length == _pubKeys20.length && _tokenIds.length == _pubKeys20.length, "PARAMETERS LENGTH MISMATCH"
    //     );
    //     peanut = IPeanut(_peanutAddress);

    //     uint256[] memory depositIndexes = new uint256[](_amounts.length);

    //     for (uint256 i = 0; i < _amounts.length; i++) {
    //         depositIndexes[i] = peanut.makeDeposit(_tokenAddress, 3, _amounts[i], _tokenIds[i], _pubKeys20[i]);
    //     }

    //     return depositIndexes;
    // }
    ///////////////////////////////////////////////////////////////////////////////////////////
}
