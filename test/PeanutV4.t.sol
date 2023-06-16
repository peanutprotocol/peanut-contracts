// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/PeanutV4.sol";
import "../src/util/ERC20Mock.sol";
import "../src/util/ERC721Mock.sol";
import "../src/util/ERC1155Mock.sol";

contract PeanutV4Test is Test {
    PeanutV4 public peanutV4;
    ERC20Mock public testToken;
    ERC721Mock public testToken721;
    ERC1155Mock public testToken1155;

    // a dummy private/public keypair to test withdrawals
    address public constant PUBKEY20 =
        address(0xaBC5211D86a01c2dD50797ba7B5b32e3C1167F9f);
    bytes32 public constant PRIVKEY = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

    function setUp() public {
        console.log("Setting up test");
        peanutV4 = new PeanutV4();
        testToken = new ERC20Mock();
        testToken721 = new ERC721Mock();
        // testToken1155 = new ERC1155Mock();

        // Mint tokens for test accounts
        testToken.mint(address(this), 1000);
        testToken721.mint(address(this), 1);
        // testToken1155.mint(address(this), 1, 1000, "");

        // Approve PeanutV4 to spend tokens
        testToken.approve(address(peanutV4), 1000);
        testToken721.setApprovalForAll(address(peanutV4), true);
        // testToken1155.setApprovalForAll(address(peanutV4), true);
    }

    function testContractCreation() public {
        assertTrue(address(peanutV4) != address(0), "Contract creation failed");
    }

    function testMakeDepositERC20() public {
        uint256 amount = 100;

        // Moved minting and approval to the setup function
        uint256 depositIndex = peanutV4.makeDeposit(
            address(testToken),
            1,
            amount,
            0,
            PUBKEY20
        );

        assertEq(depositIndex, 0, "Deposit failed");
        assertEq(peanutV4.getDepositCount(), 1, "Deposit count mismatch");
    }

    function testMakeDepositERC721() public {
        uint256 tokenId = 1;

        // Moved minting and approval to the setup function
        uint256 depositIndex = peanutV4.makeDeposit(
            address(testToken721),
            2,
            1,
            tokenId,
            PUBKEY20
        );

        assertEq(depositIndex, 0, "Deposit failed");
        assertEq(peanutV4.getDepositCount(), 1, "Deposit count mismatch");
    }

    // function testMakeDepositERC1155() public {
    //     uint256 tokenId = 1;
    //     uint256 amount = 100;

    //     // Moved minting and approval to the setup function
    //     uint256 depositIndex = peanutV4.makeDeposit(
    //         address(testToken1155),
    //         3,
    //         amount,
    //         tokenId,
    //         PUBKEY20
    //     );

    //     assertEq(depositIndex, 0, "Deposit failed");
    //     assertEq(peanutV4.getDepositCount(), 1, "Deposit count mismatch");
    // }

    function testBatchMakeDeposit() public {
        address[] memory tokenAddresses = new address[](3);
        uint8[] memory contractTypes = new uint8[](3);
        uint256[] memory amounts = new uint256[](3);
        uint256[] memory tokenIds = new uint256[](3);
        address[] memory pubKeys20 = new address[](3);

        // Deposit 1: ERC20
        tokenAddresses[0] = address(testToken);
        contractTypes[0] = 1;
        amounts[0] = 100;
        tokenIds[0] = 0;
        pubKeys20[0] = PUBKEY20;

        // Deposit 2: ERC721
        tokenAddresses[1] = address(testToken721);
        contractTypes[1] = 2;
        amounts[1] = 1;
        tokenIds[1] = 1;
        pubKeys20[1] = PUBKEY20;

        // Deposit 3: Ether
        tokenAddresses[2] = address(0);
        contractTypes[2] = 0;
        amounts[2] = 1 ether;
        tokenIds[2] = 0;
        pubKeys20[2] = PUBKEY20;        


        // Moved minting and approval to the setup function
        uint256[] memory depositIndexes = peanutV4.batchMakeDeposit{value: 1 ether}( // solhint-disable-line
            tokenAddresses,
            contractTypes,
            amounts,
            tokenIds,
            pubKeys20
        );

        assertEq(depositIndexes.length, 3, "Batch deposit failed");
        assertEq(peanutV4.getDepositCount(), 3, "Deposit count mismatch");
    }

    function test_BatchMakeDepositEther() public {
        // function batchMakeDepositEther(
        //     uint256[] calldata _amounts,
        //     address[] calldata _pubKeys20
        // ) external payable returns (uint256[] memory) {

        uint256[] memory amounts = new uint256[](3);
        address[] memory pubKeys20 = new address[](3);

        for (uint256 i = 0; i < 3; i++) {
            amounts[i] = 1 ether;
            pubKeys20[i] = PUBKEY20;
        }

        // Moved minting and approval to the setup function
        uint256[] memory depositIndexes = peanutV4.batchMakeDepositEther{value: 3 ether}(
            amounts,
            pubKeys20
        );

        assertEq(depositIndexes.length, 3, "Batch deposit failed");
        assertEq(peanutV4.getDepositCount(), 3, "Deposit count mismatch");

        // Check that the contract has the correct balance
        assertEq(address(peanutV4).balance, 3 ether, "Contract balance mismatch");
    }

    function testFail_BatchMakeDepositEther() public {
        // same as before, but testing failure cases that should revert.
        // e.g.: not sending enough ether
        uint256[] memory amounts = new uint256[](3);
        address[] memory pubKeys20 = new address[](3);

        for (uint256 i = 0; i < 3; i++) {
            amounts[i] = 1 ether;
            pubKeys20[i] = PUBKEY20;
        }

        uint256[] memory depositIndexes = peanutV4.batchMakeDepositEther{value: 2 ether}(
            amounts,
            pubKeys20
        );

        // This should fail because we didn't send enough ether
        assertEq(depositIndexes.length, 3, "Batch deposit failed");
        assertEq(peanutV4.getDepositCount(), 3, "Deposit count mismatch");        
    }

    // test sender withdrawal
    function testSenderTimeWithdraw() public {
        uint256 amount = 1000;

        assertEq(testToken.balanceOf(address(peanutV4)), 0, "Contract balance mismatch");
        // Moved minting and approval to the setup function
        uint256 depositIndex = peanutV4.makeDeposit(
            address(testToken),
            1,
            amount,
            0,
            PUBKEY20
        );

        assertEq(depositIndex, 0, "Deposit failed");
        assertEq(peanutV4.getDepositCount(), 1, "Deposit count mismatch");
        assertEq(testToken.balanceOf(address(peanutV4)), 1000, "Contract balance mismatch");
        
        // wait 25 hours
        vm.warp(block.timestamp + 25 hours);

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(depositIndex);

        // Check that the contract has the correct balance
        assertEq(testToken.balanceOf(address(peanutV4)), 0, "Contract balance mismatch");
        assertEq(testToken.balanceOf(address(this)), 1000, "Sender balance mismatch");
    }

}
