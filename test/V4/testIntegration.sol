// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

//////////////////////////////
// A few integration tests for the PeanutV4 contract
//////////////////////////////

import "@forge-std/Test.sol";
import "../../src/V4/PeanutV4.sol";
import "../../src/util/ERC20Mock.sol";
import "../../src/util/ERC721Mock.sol";
import "../../src/util/ERC1155Mock.sol";

contract PeanutV4Test is Test {
    PeanutV4 public peanutV4;
    ERC20Mock public testToken;
    ERC721Mock public testToken721;
    ERC1155Mock public testToken1155;

    // a dummy private/public keypair to test withdrawals
    address public constant PUBKEY20 =
        address(0xaBC5211D86a01c2dD50797ba7B5b32e3C1167F9f);
    bytes32 public constant PRIVKEY =
        0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

    function setUp() public {
        console.log("Setting up test");
        peanutV4 = new PeanutV4();
        testToken = new ERC20Mock();
        testToken721 = new ERC721Mock();
        testToken1155 = new ERC1155Mock();
    }

    // Make a deposit, withdraw the deposit.
    // check invariants
    function integrationTestEtherSenderWithdraw(uint128 amount) public {
        vm.assume(amount > 0);
        assertEq(peanutV4.getDepositCount(), 0); // deposit count invariant
        assertEq(address(peanutV4).balance, 0); // contract balance invariant
        uint256 senderBalance = address(this).balance; // sender balance invariant
        uint256 depositIdx = peanutV4.makeDeposit{value: amount}(
            address(0),
            0,
            amount,
            0,
            PUBKEY20
        );
        assertEq(depositIdx, 0); // deposit index invariant
        assertEq(peanutV4.getDepositCount(), 1); // deposit count invariant
        assertEq(address(peanutV4).balance, amount); // contract balance invariant
        assertEq(address(this).balance, senderBalance - amount); // sender balance invariant

        // wait 25 hours
        vm.warp(block.timestamp + 25 hours);

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(depositIdx);
        assertEq(peanutV4.getDepositCount(), 0); // deposit count invariant
        assertEq(address(peanutV4).balance, 0); // contract balance invariant
        assertEq(address(this).balance, senderBalance); // sender balance invariant
    }

    function integrationTestERC20SenderWithdraw(uint128 amount) public {
        vm.assume(amount > 0);
        // mint tokens to the contract
        testToken.mint(address(this), amount);
        assertEq(testToken.balanceOf(address(this)), amount); // contract token balance invariant
        uint256 depositIdx = peanutV4.makeDeposit(
            address(testToken),
            0,
            amount,
            0,
            PUBKEY20
        );
        assertEq(depositIdx, 0); // deposit index invariant
        assertEq(peanutV4.getDepositCount(), 1); // deposit count invariant
        assertEq(testToken.balanceOf(address(peanutV4)), amount); // contract token balance invariant
        assertEq(testToken.balanceOf(address(this)), 0); // sender token balance invariant

        // wait 25 hours
        vm.warp(block.timestamp + 25 hours);

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(depositIdx);
        assertEq(peanutV4.getDepositCount(), 0); // deposit count invariant
        assertEq(testToken.balanceOf(address(peanutV4)), 0); // contract token balance invariant
        assertEq(testToken.balanceOf(address(this)), amount); // sender token balance invariant
    }

    // Test for ERC721 Token
    function integrationTestERC721SenderWithdraw(uint256 tokenId) public {
        // mint a token to the contract
        testToken721.mint(address(this), tokenId);
        assertEq(testToken721.ownerOf(tokenId), address(this)); // token ownership invariant
        uint256 depositIdx = peanutV4.makeDeposit(
            address(testToken721),
            2,
            1,
            tokenId,
            PUBKEY20
        );
        assertEq(depositIdx, 0); // deposit index invariant
        assertEq(peanutV4.getDepositCount(), 1); // deposit count invariant
        assertEq(testToken721.ownerOf(tokenId), address(peanutV4)); // token ownership invariant

        // wait 25 hours
        vm.warp(block.timestamp + 25 hours);

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(depositIdx);
        assertEq(peanutV4.getDepositCount(), 0); // deposit count invariant
        assertEq(testToken721.ownerOf(tokenId), address(this)); // token ownership invariant
    }

    // Test for ERC1155 Token
    function integrationTestERC1155SenderWithdraw(
        uint256 tokenId,
        uint256 amount
    ) public {
        vm.assume(amount > 0);
        // mint tokens to the contract
        testToken1155.mint(address(this), tokenId, amount, "");
        assertEq(testToken1155.balanceOf(address(this), tokenId), amount); // contract token balance invariant
        uint256 depositIdx = peanutV4.makeDeposit(
            address(testToken1155),
            3,
            amount,
            tokenId,
            PUBKEY20
        );
        assertEq(depositIdx, 0); // deposit index invariant
        assertEq(peanutV4.getDepositCount(), 1); // deposit count invariant
        assertEq(testToken1155.balanceOf(address(peanutV4), tokenId), amount); // contract token balance invariant
        assertEq(testToken1155.balanceOf(address(this), tokenId), 0); // sender token balance invariant

        // wait 25 hours
        vm.warp(block.timestamp + 25 hours);

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(depositIdx);
        assertEq(peanutV4.getDepositCount(), 0); // deposit count invariant
        assertEq(testToken1155.balanceOf(address(peanutV4), tokenId), 0); // contract token balance invariant
        assertEq(testToken1155.balanceOf(address(this), tokenId), amount); // sender token balance invariant
    }
}
