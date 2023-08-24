// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@forge-std/Test.sol";
import "../../src/V4/PeanutBatcher.sol";
import "../../src/V4/PeanutV4.sol";
import "../../src/util/ERC20Mock.sol";
import "../../src/util/ERC721Mock.sol";
import "../../src/util/ERC1155Mock.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract PeanutBatcherTest is Test, ERC1155Holder, ERC721Holder {
    PeanutBatcher public batcher;
    PeanutV4 public peanutV4;
    ERC20Mock public testToken;
    ERC721Mock public testToken721;
    ERC1155Mock public testToken1155;
    address public PUBKEY20 = address(0xaBC5211D86a01c2dD50797ba7B5b32e3C1167F9f);

    function setUp() public {
        batcher = new PeanutBatcher();
        peanutV4 = new PeanutV4();
        testToken = new ERC20Mock();
        testToken721 = new ERC721Mock();
        testToken1155 = new ERC1155Mock();
    }

    // make contract payable
    receive() external payable {}

    // Test making a batch deposit of ERC20 tokens
    function testBaseEtherDeposit() public {
        uint64 amount = 100;
        uint64 numDeposits = 10;
        address[] memory pubKeys20 = new address[](numDeposits);
        for (uint256 i = 0; i < numDeposits; i++) {
            pubKeys20[i] = PUBKEY20;
        }

        uint256 totalAmount = amount * numDeposits;
        // make the batch deposit
        uint256[] memory depositIndexes =
            batcher.batchMakeDeposit{value: totalAmount}(address(peanutV4), address(0), 0, amount, 0, pubKeys20);
        // check that the correct number of deposits were made
        assertEq(depositIndexes.length, numDeposits);
    }

    // Test making a batch deposit of ERC20 tokens
    function testBatchERC20Deposit() public {
        uint64 amount = 100;
        uint64 numDeposits = 10;
        address[] memory pubKeys20 = new address[](numDeposits);
        for (uint256 i = 0; i < numDeposits; i++) {
            pubKeys20[i] = PUBKEY20;
        }
        // mint tokens to the caller
        testToken.mint(address(this), amount * numDeposits);
        testToken.approve(address(batcher), amount * numDeposits);

        // console.log("Balance: ", testToken.balanceOf(msg.sender));
        // // approve the PeanutV4 contract to spend the tokens
        // console.log("Allowance: ", testToken.allowance(msg.sender, address(peanutV4)));
        // console.log("Allowance: ", testToken.allowance(msg.sender, address(batcher)));
        // // print my address
        // console.log("My address: ", msg.sender);
        // // print tx initiator
        // console.log("Tx initiator: ", tx.origin);
        // // print all balances for all and allowances of the testToken
        // console.log("Balance: ", testToken.balanceOf(msg.sender));
        // console.log("Allowance: ", testToken.allowance(msg.sender, address(peanutV4)));
        // console.log("Allowance: ", testToken.allowance(msg.sender, address(batcher)));
        // console.log("Balance: ", testToken.balanceOf(address(peanutV4)));
        // console.log("Balance: ", testToken.balanceOf(address(batcher)));
        // console.log("Allowance: ", testToken.allowance(address(peanutV4), address(batcher)));
        // console.log("Allowance: ", testToken.allowance(address(batcher), address(peanutV4)));
        // // check how many tokens have been minted
        // console.log("Total supply: ", testToken.totalSupply());
        // // get the balances object
        // console.log(address(this));
        // console.log(address(peanutV4));
        // console.log(address(batcher));
        // console.log(address(testToken));
        // console.log("Allowance for address(this): ", testToken.allowance(address(this), address(peanutV4)));
        // console.log("Allowance for address(this): ", testToken.allowance(address(this), address(batcher)));

        // make the batch deposit
        uint256[] memory depositIndexes =
            batcher.batchMakeDeposit(address(peanutV4), address(testToken), 1, amount, 0, pubKeys20);
        // check that the correct number of deposits were made
        assertEq(depositIndexes.length, numDeposits);
    }

    // Test making a batch deposit of ERC721 tokens
    function testBatchERC721Deposit() public {
        uint64 numDeposits = 10;
        address[] memory pubKeys20 = new address[](numDeposits);
        for (uint256 i = 0; i < numDeposits; i++) {
            uint64 tokenId = uint64(i);
            pubKeys20[i] = PUBKEY20;
            // mint a token to the caller
            testToken721.mint(msg.sender, tokenId);
            // approve the PeanutV4 contract to spend the tokens
            testToken721.approve(address(batcher), tokenId);
        }
        // make the batch deposit
        uint256[] memory depositIndexes =
            batcher.batchMakeDeposit(address(peanutV4), address(testToken721), 2, 1, numDeposits, pubKeys20);
        // check that the correct number of deposits were made
        assertEq(depositIndexes.length, numDeposits);
    }

    // Test making a batch deposit of ERC1155 tokens
    function testBatchERC1155Deposit() public {
        uint64 numDeposits = 10;
        address[] memory pubKeys20 = new address[](numDeposits);

        for (uint256 i = 0; i < numDeposits; i++) {
            uint64 tokenId = uint64(i);
            pubKeys20[i] = PUBKEY20;
            // mint a token to the caller
            testToken1155.mint(msg.sender, tokenId, 1, "");
            // approve the PeanutV4 contract to spend the tokens
            testToken1155.setApprovalForAll(address(batcher), true);
        }
        // make the batch deposit
        uint256[] memory depositIndexes =
            batcher.batchMakeDeposit(address(peanutV4), address(testToken1155), 3, 1, numDeposits, pubKeys20);
        // check that the correct number of deposits were made
        assertEq(depositIndexes.length, numDeposits);
    }

    // Test failure case where PeanutV4 contract is not approved to spend ERC20 tokens
    function testFailBatchERC20DepositNotApproved() public {
        uint64 amount = 100;
        uint64 numDeposits = 10;
        address[] memory pubKeys20 = new address[](numDeposits);
        for (uint256 i = 0; i < numDeposits; i++) {
            pubKeys20[i] = PUBKEY20;
        }
        // mint tokens to the caller
        testToken.mint(msg.sender, amount * numDeposits);
        // Do NOT approve the PeanutV4 contract to spend the tokens
        // testToken.approve(address(peanutV4), amount * numDeposits);
        // make the batch deposit
        uint256[] memory depositIndexes =
            batcher.batchMakeDeposit(address(peanutV4), address(testToken), 1, amount, 0, pubKeys20);
        depositIndexes;
    }

    // Test failure case where PeanutV4 contract is not approved to spend ERC721 tokens
    function testFailBatchERC721DepositNotApproved() public {
        uint64 numDeposits = 10;
        address[] memory pubKeys20 = new address[](numDeposits);
        for (uint256 i = 0; i < numDeposits; i++) {
            uint64 tokenId = uint64(i);
            pubKeys20[i] = PUBKEY20;
            // mint a token to the caller
            testToken721.mint(msg.sender, tokenId);
            // Do NOT approve the PeanutV4 contract to spend the tokens
            // testToken721.approve(address(peanutV4), tokenId);
        }
        // make the batch deposit
        uint256[] memory depositIndexes =
            batcher.batchMakeDeposit(address(peanutV4), address(testToken721), 2, 1, numDeposits, pubKeys20);
        depositIndexes;
    }

    // Test failure case where PeanutV4 contract is not approved to spend ERC1155 tokens
    function testFailBatchERC1155DepositNotApproved() public {
        uint64 numDeposits = 10;
        address[] memory pubKeys20 = new address[](numDeposits);
        for (uint256 i = 0; i < numDeposits; i++) {
            uint64 tokenId = uint64(i);
            pubKeys20[i] = PUBKEY20;
            // mint a token to the caller
            testToken1155.mint(msg.sender, tokenId, 1, "");
            // Do NOT approve the PeanutV4 contract to spend the tokens
            // testToken1155.setApprovalForAll(address(peanutV4), true);
        }
        // make the batch deposit
        uint256[] memory depositIndexes =
            batcher.batchMakeDeposit(address(peanutV4), address(testToken1155), 3, 1, numDeposits, pubKeys20);
        depositIndexes;
    }
}
