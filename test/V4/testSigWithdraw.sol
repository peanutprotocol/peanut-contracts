// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/V4/PeanutV4.sol";
import "../../src/util/ERC20Mock.sol";
import "../../src/util/ERC721Mock.sol";
import "../../src/util/ERC1155Mock.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract TestSigWithdrawEther is Test {
    PeanutV4 public peanutV4;

    // sample inputs
    address _pubkey20 = 0x8fd379246834eac74B8419FfdA202CF8051F7A03;
    address _recipientAddress = 0x6B3751c5b04Aa818EA90115AA06a4D9A36A16f02;
    bytes public signatureAnybody =
        hex"02a37d0548c14c6b07eba4ef1438eb946cdada4f481164755129eb3725f7e8c13d7c052308e73314338f4d484a5f4aef20c7519a1dbc283e4826253b742817241c";
    bytes public signatureRecipient = hex"364c17bca8823977b29b7646c954353996f363549f08ce3943969171c050f0d74006eabb597df680e9e4229631f473bfbedf995336a03d2fd3be7f1fff22d2511b";

    receive() external payable {} // necessary to receive ether

    function setUp() public {
        console.log("Setting up test");
        peanutV4 = new PeanutV4(address(0));
    }

    // test sender withdrawal of ETH
    function testSigWithdrawEther(uint64 amount) public {
        vm.assume(amount > 0);
        uint256 depositIdx = peanutV4.makeDeposit{value: amount}(address(0), 0, amount, 0, _pubkey20);

        // Can't use withdrawDepositAsRecipient
        vm.expectRevert("NOT THE RECIPIENT");
        peanutV4.withdrawDepositAsRecipient(depositIdx, _recipientAddress, signatureAnybody);

        // Anybody can withdraw
        peanutV4.withdrawDeposit(depositIdx, _recipientAddress, signatureAnybody);
    }

    function testWithdrawDepositAsRecipient(uint64 amount) public {
        vm.assume(amount > 0);
        uint256 depositIdx = peanutV4.makeDeposit{value: amount}(address(0), 0, amount, 0, _pubkey20);

        // Can't use pure withdrawDeposit
        vm.expectRevert("WRONG SIGNATURE");
        peanutV4.withdrawDeposit(depositIdx, _recipientAddress, signatureRecipient);
        
        // Only the recipient is able to withdraw via withdrawDepositAsRecipient
        vm.expectRevert("NOT THE RECIPIENT");
        peanutV4.withdrawDepositAsRecipient(depositIdx, _recipientAddress, signatureRecipient);

        vm.prank(_recipientAddress);  // Withdraw!
        peanutV4.withdrawDepositAsRecipient(depositIdx, _recipientAddress, signatureRecipient);
    }
}
