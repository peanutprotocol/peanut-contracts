// SPDX-License-Identifier:
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/V4/PeanutV4.sol";
import "../../src/util/ERC20Mock.sol";
import "../../src/util/ERC721Mock.sol";
import "../../src/util/ERC1155Mock.sol";

contract testSenderWithdrawEther is Test {
    PeanutV4 public peanutV4;
    // a dummy private/public keypair to test withdrawals
    address public constant PUBKEY20 =
        address(0xaBC5211D86a01c2dD50797ba7B5b32e3C1167F9f);
    bytes32 public constant PRIVKEY =
        0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;
    
    receive() external payable {} // necessary to receive ether

    function setUp() public {
        console.log("Setting up test");
        peanutV4 = new PeanutV4();
    }

    // test sender withdrawal of ERC20
    function testSenderTimeWithdrawEther(uint64 amount) public {
        vm.assume(amount > 0);
        uint256 depositIdx = peanutV4.makeDeposit{value: amount}(
            address(0),
            0,
            amount,
            0,
            PUBKEY20
        );

        // wait 25 hours
        vm.warp(block.timestamp + 25 hours);

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(depositIdx);
    }

    function testFailSenderTimeWithdrawEther(uint64 amount) public {
        vm.assume(amount > 0);
        uint256 depositIdx = peanutV4.makeDeposit{value: amount}(
            address(0),
            0,
            amount,
            0,
            PUBKEY20
        );

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(depositIdx);
    }

    function testFailSenderTimeWithdrawEther1Hour(uint64 amount) public {
        vm.assume(amount > 0);
        uint256 depositIdx = peanutV4.makeDeposit{value: amount}(
            address(0),
            0,
            amount,
            0,
            PUBKEY20
        );

        // wait 1 hour
        vm.warp(block.timestamp + 1 hours);

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(depositIdx);
    }
}

contract testSenderWithdrawERC20 is Test {
    PeanutV4 public peanutV4;
    ERC20Mock public testToken;

    // a dummy private/public keypair to test withdrawals
    address public constant PUBKEY20 =
        address(0xaBC5211D86a01c2dD50797ba7B5b32e3C1167F9f);
    bytes32 public constant PRIVKEY =
        0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

    uint256 depositIdx;

    // apparently not possible to fuzz test in setUp() function?
    function setUp() public {
        console.log("Setting up test");
        peanutV4 = new PeanutV4();
        testToken = new ERC20Mock(); // contractype 1

        // Mint tokens for test accounts (larger than uint128)
        testToken.mint(address(this), 2**130);

        // Approve the contract to spend the tokens
        testToken.approve(address(peanutV4), 2**130);

        // Make a deposit
        uint256 amount = 2**128;
        depositIdx = peanutV4.makeDeposit(
            address(testToken),
            1,
            amount,
            0,
            PUBKEY20
        );
    }

    // test sender withdrawal of ERC20
    function testSenderTimeWithdrawERC20() public {
        // wait 25 hours
        vm.warp(block.timestamp + 25 hours);

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(depositIdx);
    }

    function testFailSenderTimeWithdrawERC20_Immediate() public {
        // Withdraw the deposit
        peanutV4.withdrawDepositSender(depositIdx);
    }

    function testFailSenderTimeWithdrawERC20_1Hour() public {
        // wait 1 hour
        vm.warp(block.timestamp + 1 hours);

        // Withdraw the deposit
        peanutV4.withdrawDepositSender(depositIdx);
    }
}
