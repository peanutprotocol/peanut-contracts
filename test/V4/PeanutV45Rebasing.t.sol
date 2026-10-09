// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {PeanutV4} from "../../src/V4/PeanutV4.5.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract RebasingTokenFixture is ERC20 {
    uint256 public linearInflationMultiplier = 2;
    bool public rejectTransfer;
    constructor() ERC20("Rebasing fixture", "RF") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setMultiplier(uint256 multiplier) external {
        linearInflationMultiplier = multiplier;
    }

    function setRejectTransfer(bool value) external {
        rejectTransfer = value;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (rejectTransfer) return false;
        return super.transfer(to, amount);
    }
}

contract PeanutV45RebasingTest is Test {
    PeanutV4 vault;
    RebasingTokenFixture token;
    uint256 constant KEY = 0x12345;
    address recipient = address(0xBEEF);
    address storedSender = address(0xCAFE);

    function setUp() public {
        token = new RebasingTokenFixture();
        vault = new PeanutV4(address(token));
        token.mint(address(this), 1000);
        token.approve(address(vault), type(uint256).max);
    }

    function signature(uint256 index, bytes32 mode) internal returns (bytes memory) {
        bytes32 digest = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encodePacked(vault.PEANUT_SALT(), block.chainid, address(vault), index, recipient, mode))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function deposit(bool mfa, bool bound) internal returns (uint256) {
        return vault.makeCustomDeposit(
            address(token),
            4,
            100,
            0,
            vm.addr(KEY),
            storedSender,
            mfa,
            bound ? recipient : address(0),
            uint40(block.timestamp + 1 days),
            false,
            ""
        );
    }

    function assertRecipientPaid(uint256 amount) internal {
        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.balanceOf(storedSender), 0);
        assertEq(token.balanceOf(address(this)), 900);
    }

    function testNormalClaimPaysRecipient() public {
        uint256 index = deposit(false, false);
        vault.withdrawDeposit(index, recipient, signature(index, vault.ANYONE_WITHDRAWAL_MODE()));
        assertRecipientPaid(100);
        assertTrue(vault.getDeposit(index).claimed);
    }

    function testRecipientOnlyClaimPaysRecipientAfterRebase() public {
        uint256 index = deposit(false, false);
        token.setMultiplier(4);
        bytes memory sig = signature(index, vault.RECIPIENT_WITHDRAWAL_MODE());
        vm.prank(recipient);
        vault.withdrawDepositAsRecipient(index, recipient, sig);
        assertRecipientPaid(50);
    }

    function testMFAClaimPaysRecipient() public {
        uint256 index = deposit(true, false);
        bytes memory sig = signature(index, vault.ANYONE_WITHDRAWAL_MODE());
        vm.expectRevert("REQUIRES AUTHORIZATION");
        vault.withdrawDeposit(index, recipient, sig);
        bytes32 digest = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encodePacked(vault.PEANUT_SALT(), block.chainid, address(vault), index, recipient))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x6789, digest);
        bytes memory authorization = abi.encodePacked(r, s, v);
        vm.expectRevert("WRONG MFA SIGNATURE");
        vault.withdrawMFADeposit(index, recipient, sig, authorization);
        // The deployed MFA authority has no test private key; mock only its recovery precompile input.
        vm.mockCall(address(1), abi.encode(digest, uint256(v), r, s), abi.encode(vault.MFA_AUTHORIZER()));
        vault.withdrawMFADeposit(index, recipient, sig, authorization);
        assertRecipientPaid(100);
    }

    function testRecipientBoundClaimPaysRecipient() public {
        uint256 index = vault.makeCustomDeposit(
            address(token),
            4,
            100,
            0,
            address(0),
            storedSender,
            false,
            recipient,
            uint40(block.timestamp + 1 days),
            false,
            ""
        );
        vault.withdrawDeposit(index, recipient, "");
        assertRecipientPaid(100);
    }

    function testSenderReclaimStillPaysStoredSender() public {
        uint256 index = deposit(false, false);
        vm.prank(storedSender);
        vault.withdrawDepositSender(index);
        assertEq(token.balanceOf(storedSender), 100);
        assertEq(token.balanceOf(recipient), 0);
    }

    function testBoundSenderCannotReclaimBeforeDeadline() public {
        uint256 index = deposit(false, true);
        vm.prank(storedSender);
        vm.expectRevert();
        vault.withdrawDepositSender(index);
        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(storedSender);
        vault.withdrawDepositSender(index);
        assertEq(token.balanceOf(storedSender), 100);
    }

    function testRejectedTransferDoesNotConsumeDeposit() public {
        uint256 index = deposit(false, false);
        token.setRejectTransfer(true);
        bytes memory sig = signature(index, vault.ANYONE_WITHDRAWAL_MODE());
        vm.expectRevert("TRANSFER FAILED");
        vault.withdrawDeposit(index, recipient, sig);
        assertFalse(vault.getDeposit(index).claimed);
        assertEq(token.balanceOf(recipient), 0);
        token.setRejectTransfer(false);
        vault.withdrawDeposit(index, recipient, sig);
        assertRecipientPaid(100);
    }
}
