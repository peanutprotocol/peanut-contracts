// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./PeanutV4.4.sol";

contract PeanutBatcherV4 {
    using SafeERC20 for IERC20;

    PeanutV4 public peanut;

    function _setAllowanceIfZero(address tokenAddress, address spender) internal {
        uint256 currentAllowance = IERC20(tokenAddress).allowance(address(this), spender);
        if (currentAllowance == 0) {
            IERC20(tokenAddress).safeApprove(spender, type(uint256).max);
        }
    }

    function batchMakeDeposit(
        address _peanutAddress,
        address _tokenAddress,
        uint8 _contractType,
        uint256 _amount,
        uint256 _tokenId,
        address[] calldata _pubKeys20
    ) external payable returns (uint256[] memory) {
        peanut = PeanutV4(_peanutAddress);
        uint256 totalAmount = _amount * _pubKeys20.length;
        uint256 etherAmount;

        if (_contractType == 0) {
            require(msg.value == totalAmount, "INVALID TOTAL ETHER SENT");
            etherAmount = _amount;
        } else if (_contractType == 1) {
            IERC20(_tokenAddress).safeTransferFrom(msg.sender, address(this), totalAmount);
            _setAllowanceIfZero(_tokenAddress, address(peanut));
            etherAmount = 0;
        } else if (_contractType == 2) {
            // revert not implemented
            revert("ERC721 batch not implemented");
        } else if (_contractType == 3) {
            IERC1155(_tokenAddress).safeTransferFrom(msg.sender, address(this), _tokenId, totalAmount, "");
            IERC1155(_tokenAddress).setApprovalForAll(address(peanut), true);
            etherAmount = 0;
        }

        uint256[] memory depositIndexes = new uint256[](_pubKeys20.length);

        for (uint256 i = 0; i < _pubKeys20.length; i++) {
            depositIndexes[i] =
                peanut.makeSelflessDeposit{value: etherAmount}(_tokenAddress, _contractType, _amount, _tokenId, _pubKeys20[i], msg.sender);
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
        peanut = PeanutV4(_peanutAddress);

        for (uint256 i = 0; i < _pubKeys20.length; i++) {
            peanut.makeSelflessDeposit{value: msg.value}(_tokenAddress, _contractType, _amount, _tokenId, _pubKeys20[i], msg.sender);
        }
    }

    // arbitrary deposits
    function batchMakeDepositArbitrary(
        address _peanutAddress,
        address[] memory _tokenAddresses,
        uint8[] memory _contractTypes,
        uint256[] calldata _amounts,
        uint256[] calldata _tokenIds,
        address[] calldata _pubKeys20
    ) external payable returns (uint256[] memory) {
        require(
            _tokenAddresses.length == _pubKeys20.length && _contractTypes.length == _pubKeys20.length
                && _amounts.length == _pubKeys20.length && _tokenIds.length == _pubKeys20.length,
            "PARAMETERS LENGTH MISMATCH"
        );
        peanut = PeanutV4(_peanutAddress);

        uint256[] memory depositIndexes = new uint256[](_amounts.length);

        for (uint256 i = 0; i < _amounts.length; i++) {
            uint256 etherAmount;

            if (_contractTypes[i] == 0) {
                etherAmount = _amounts[i];
            } else if (_contractTypes[i] == 1) {
                IERC20(_tokenAddresses[i]).safeTransferFrom(msg.sender, address(this), _amounts[i]);
                _setAllowanceIfZero(_tokenAddresses[i], _peanutAddress);
                etherAmount = 0;
            } else if (_contractTypes[i] == 2) {
                // revert not implemented
                revert("ERC721 batch not implemented");
            } else if (_contractTypes[i] == 3) {
                IERC1155(_tokenAddresses[i]).safeTransferFrom(msg.sender, address(this), _tokenIds[i], _amounts[i], "");
                IERC1155(_tokenAddresses[i]).setApprovalForAll(_peanutAddress, true);
                etherAmount = 0;
            }

            depositIndexes[i] = peanut.makeSelflessDeposit{value: etherAmount}(
                _tokenAddresses[i], _contractTypes[i], _amounts[i], _tokenIds[i], _pubKeys20[i], msg.sender
            );
        }

        return depositIndexes;
    }

    function batchMakeDepositRaffle(
        address _peanutAddress,
        address _tokenAddress,
        uint8 _contractType,
        uint256[] calldata _amounts,
        address _pubKey20
    ) external payable returns (uint256[] memory) {
        require(
            _contractType == 0 || _contractType == 1,
            "ONLY ETH AND ERC20 RAFFLES ARE SUPPORTED"
        );

        peanut = PeanutV4(_peanutAddress);
        if (_contractType == 1) {
            _setAllowanceIfZero(_tokenAddress, _peanutAddress);
            uint256 totalAmount;
            for(uint256 i = 0; i < _amounts.length; i++) {
                totalAmount += _amounts[i];
            }
            IERC20(_tokenAddress).safeTransferFrom(msg.sender, address(this), totalAmount);
        }

        uint256[] memory depositIndexes = new uint256[](_amounts.length);

        for (uint256 i = 0; i < _amounts.length; i++) {
            uint256 etherAmount;

            if (_contractType == 0) {
                etherAmount = _amounts[i];
            }

            depositIndexes[i] = peanut.makeSelflessDeposit{value: etherAmount}(
                _tokenAddress, _contractType, _amounts[i], 0, _pubKey20, msg.sender
            );
        }

        return depositIndexes;
    }

    function batchMakeDepositRaffleMFA(
        address _peanutAddress,
        address _tokenAddress,
        uint8 _contractType,
        uint256[] calldata _amounts,
        address _pubKey20
    ) external payable returns (uint256[] memory) {
        require(
            _contractType == 0 || _contractType == 1,
            "ONLY ETH AND ERC20 RAFFLES ARE SUPPORTED"
        );

        peanut = PeanutV4(_peanutAddress);
        if (_contractType == 1) {
            _setAllowanceIfZero(_tokenAddress, _peanutAddress);
            uint256 totalAmount;
            for(uint256 i = 0; i < _amounts.length; i++) {
                totalAmount += _amounts[i];
            }
            IERC20(_tokenAddress).safeTransferFrom(msg.sender, address(this), totalAmount);
        }

        uint256[] memory depositIndexes = new uint256[](_amounts.length);

        for (uint256 i = 0; i < _amounts.length; i++) {
            uint256 etherAmount;

            if (_contractType == 0) {
                etherAmount = _amounts[i];
            }

            depositIndexes[i] = peanut.makeSelflessMFADeposit{value: etherAmount}(
                _tokenAddress, _contractType, _amounts[i], 0, _pubKey20, msg.sender
            );
        }

        return depositIndexes;
    }
}
