// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

//////////////////////////////////////////////////////////////////////////////////////
// @title   Peanut Router
// @notice  This contract is used on top of Peanut V4.2 to add cross-chain functionality to links.
//          more at: https://peanut.to
// @version 0.1.0
// @author  Squirrel Labs
//////////////////////////////////////////////////////////////////////////////////////
//⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
//                         ⠀⠀⢀⣀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣶⣶⣦⣌⠙⠋⢡⣴⣶⡄⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⣿⣿⣿⡿⢋⣠⣶⣶⡌⠻⣿⠟⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⡆⠸⠟⢁⣴⣿⣿⣿⣿⣿⡦⠉⣴⡇⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣾⣿⠟⠀⠰⣿⣿⣿⣿⣿⣿⠟⣠⡄⠹⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡀⢸⡿⢋⣤⣿⣄⠙⣿⣿⡿⠟⣡⣾⣿⣿⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⣠⣴⣾⠿⠀⢠⣾⣿⣿⣿⣦⠈⠉⢠⣾⣿⣿⣿⠏⠀⠀⠀
// ⠀⠀⠀⠀⣀⣤⣦⣄⠙⠋⣠⣴⣿⣿⣿⣿⠿⠛⢁⣴⣦⡄⠙⠛⠋⠁⠀⠀⠀⠀
// ⠀⠀⢀⣾⣿⣿⠟⢁⣴⣦⡈⠻⣿⣿⡿⠁⡀⠚⠛⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠘⣿⠟⢁⣴⣿⣿⣿⣿⣦⡈⠛⢁⣼⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⢰⡦⠀⢴⣿⣿⣿⣿⣿⣿⣿⠟⢀⠘⠿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠘⢀⣶⡀⠻⣿⣿⣿⣿⡿⠋⣠⣿⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⢿⣿⣿⣦⡈⠻⣿⠟⢁⣼⣿⣿⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠈⠻⣿⣿⣿⠖⢀⠐⠿⠟⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠈⠉⠁⠀⠀⠀⠀⠀
//
//////////////////////////////////////////////////////////////////////////////////////

import {PeanutV4} from "./PeanutV4.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract PeanutV4Router is Ownable {
    using SafeERC20 for IERC20;

    address public squidAddress;

    constructor(address _squidAddress) {
        squidAddress = _squidAddress;
    }

     /**
     * @notice Function to withdraw a peanut deposit to a different chain.
     * @dev We could include something like "expiry" in this function to prevent X-chain
     * transfers getting stuck in Axelar (Squid works on top of Axelar) in case gas price
     * on the destination chain increases while the tx is pending in the mempool on the source chain.
     * But it doesn't really matter since all transfers are paid by us and we can always increase
     * the axelar fee (e.g. from our backend server).
     * @param _peanutAddress peanut vault to withdraw the deposit from.
     * @param _depositIndex index of the deposit in the peanut vault.
     * @param _withdrawalSignature signature to withdraw from peanut.
     * @param _squidFee squid router fee.
     * @param _peanutFee fee amount taken by peanut (this contract) for routing.
     * @param _squidData calldata for the squid router
     * @param _routingSignature signed _squidFee, _peanutFee and _squidData
     */
    function withdrawAndBridge(
        address _peanutAddress,
        uint256 _depositIndex,
        bytes calldata _withdrawalSignature,
        uint256 _squidFee,
        uint256 _peanutFee,
        bytes calldata _squidData,
        bytes calldata _routingSignature
    ) public payable {
        PeanutV4 peanut = PeanutV4(_peanutAddress);
        PeanutV4.Deposit memory deposit = peanut.getDeposit(_depositIndex);

        // We must first validate _routingSignature to prevent front-running
        // The signature structure follows version 0x00 from EIP-191
        bytes32 digest = keccak256(
            abi.encodePacked(
                bytes2(0x1900),
                address(this),
                block.chainid,
                _peanutAddress,
                _depositIndex,
                squidAddress,
                _squidFee,
                _peanutFee,
                _squidData
            )
        );
        address routingSigner = ECDSA.recover(digest, _routingSignature);
        require(routingSigner == deposit.pubKey20, "WRONG ROUTING SIGNER");

        require(_squidFee == msg.value, "msg.value MUST BE THE SQUID FEE");
        require(deposit.contractType == 0 || deposit.contractType == 1, "X-CHAIN CLAIMS WORK ONLY FOR ETH AND ERC20 TOKENS");
        require(_peanutFee < deposit.amount, "TOO HIGH FEE");

        peanut.withdrawDepositAsRecipient(_depositIndex, address(this), _withdrawalSignature);

        uint256 amountToBridge = deposit.amount - _peanutFee;
        uint256 ethAmountToSquid = msg.value;
        if (deposit.contractType == 0) { // ETH deposit
            ethAmountToSquid += amountToBridge;
        } else if (deposit.contractType == 1) { // ERC20 deposit
            IERC20(deposit.tokenAddress).safeIncreaseAllowance(address(squidAddress), amountToBridge);
        } else {
            revert("UNSUPPORTED contractType");
        }

        // initiate the cross-chain transfer
        (bool success,) = payable(squidAddress).call{value: ethAmountToSquid}(_squidData);
        require(success, "FAILED TO INITIATE SQUID TRANSFER");
    }

    function withdrawFees(address token, address to, uint256 amount) public onlyOwner {
        if (token == address(0)) {
            (bool success,) = payable(to).call{value: amount}("");
            require(success, "FAILED TO WITHDRAW ETH");
        } else {
            IERC20(token).transfer(to, amount);
        }
    }

    receive() external payable {} // allow ETH transfers from peanut vault
}
