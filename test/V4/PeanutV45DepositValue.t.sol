// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {PeanutV4} from "../../src/V4/PeanutV4.5.sol";
import {ERC20Mock} from "../../src/util/ERC20Mock.sol";
import {ERC721Mock} from "../../src/util/ERC721Mock.sol";
import {ERC1155Mock} from "../../src/util/ERC1155Mock.sol";
import {RebasingTokenFixture} from "./PeanutV45Rebasing.t.sol";

contract PeanutV45DepositValueTest is Test {
    PeanutV4 vault;
    ERC20Mock token;
    ERC721Mock nft;
    ERC1155Mock multi;
    RebasingTokenFixture eco;
    uint256 constant KEY = 0x12345;
    address sender;
    address constant PUBKEY = address(0xBEEF);

    function setUp() public {
        sender = vm.addr(KEY);
        vm.deal(sender, 100 ether);
        token = new ERC20Mock();
        nft = new ERC721Mock();
        multi = new ERC1155Mock();
        eco = new RebasingTokenFixture();
        vault = new PeanutV4(address(eco));
        token.mint(sender, 1000);
        nft.mint(sender, 1);
        multi.mint(sender, 1, 1000, "");
        eco.mint(sender, 1000);
        vm.startPrank(sender);
        token.approve(address(vault), type(uint256).max);
        nft.setApprovalForAll(address(vault), true);
        multi.setApprovalForAll(address(vault), true);
        eco.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function deposit(uint8 entry, uint8 kind, uint256 value) internal returns (uint256) {
        address asset =
            kind == 1 ? address(token) : kind == 2 ? address(nft) : kind == 3 ? address(multi) : address(eco);
        vm.prank(sender);
        if (entry == 0) return vault.makeDeposit{value: value}(asset, kind, 1, 1, PUBKEY);
        if (entry == 1) return vault.makeMFADeposit{value: value}(asset, kind, 1, 1, PUBKEY);
        if (entry == 2) return vault.makeSelflessDeposit{value: value}(asset, kind, 1, 1, PUBKEY, sender);
        if (entry == 3) return vault.makeSelflessMFADeposit{value: value}(asset, kind, 1, 1, PUBKEY, sender);
        return vault.makeCustomDeposit{value: value}(asset, kind, 1, 1, PUBKEY, sender, false, address(0), 0, false, "");
    }

    function testEveryApprovalEntryRejectsEthForEveryTokenType() public {
        for (uint8 entry; entry < 5; entry++) {
            for (uint8 kind = 1; kind < 5; kind++) {
                vm.expectRevert("ETH NOT ACCEPTED FOR TOKEN DEPOSITS");
                deposit(entry, kind, 1);
                assertEq(vault.getDepositCount(), 0);
                assertEq(address(vault).balance, 0);
                assertEq(sender.balance, 100 ether);
                assertEq(token.balanceOf(sender), 1000);
                assertEq(eco.balanceOf(sender), 1000);
                assertEq(nft.ownerOf(1), sender);
                assertEq(multi.balanceOf(sender, 1), 1000);
            }
        }
    }

    function testEveryApprovalEntryAcceptsZeroValueTokens() public {
        for (uint8 entry; entry < 5; entry++) {
            uint256 snapshot = vm.snapshot();
            for (uint8 kind = 1; kind < 5; kind++) {
                deposit(entry, kind, 0);
            }
            assertEq(vault.getDepositCount(), 4);
            assertEq(token.balanceOf(address(vault)), 1);
            assertEq(eco.balanceOf(address(vault)), 1);
            assertEq(nft.ownerOf(1), address(vault));
            assertEq(multi.balanceOf(address(vault), 1), 1);
            assertEq(address(vault).balance, 0);
            vm.revertTo(snapshot);
        }
    }

    function testEveryApprovalEntryPreservesExactNativeValueRequirement() public {
        for (uint8 entry; entry < 5; entry++) {
            vm.expectRevert("WRONG ETH AMOUNT");
            deposit(entry, 0, 0);
            vm.expectRevert("WRONG ETH AMOUNT");
            deposit(entry, 0, 2);
            uint256 index = deposit(entry, 0, 1);
            assertEq(vault.getDeposit(index).amount, 1);
        }
        assertEq(vault.getDepositCount(), 5);
        assertEq(address(vault).balance, 5);
    }

    function testGaslessEthRejectionPreservesValidAuthorizationForRetry() public {
        bytes32 nonce = bytes32(uint256(42));
        bytes32 authorizationNonce = keccak256(abi.encodePacked(PUBKEY, nonce));
        bytes32 payload = keccak256(
            abi.encode(
                keccak256(
                    "ReceiveWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)"
                ),
                sender,
                address(vault),
                uint256(100),
                block.timestamp - 1,
                block.timestamp + 1,
                authorizationNonce
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), payload));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(KEY, digest);
        bytes memory args = abi.encode(sender, nonce, block.timestamp - 1, block.timestamp + 1, v, r, s);
        vm.prank(sender);
        vm.expectRevert("ETH NOT ACCEPTED FOR TOKEN DEPOSITS");
        vault.makeCustomDeposit{value: 1}(address(token), 1, 100, 0, PUBKEY, sender, false, address(0), 0, true, args);
        assertFalse(token.authorizationState(sender, authorizationNonce));
        assertEq(vault.getDepositCount(), 0);
        assertEq(address(vault).balance, 0);
        assertEq(sender.balance, 100 ether);
        assertEq(token.balanceOf(sender), 1000);
        vm.prank(sender);
        vault.makeCustomDeposit(address(token), 1, 100, 0, PUBKEY, sender, false, address(0), 0, true, args);
        assertTrue(token.authorizationState(sender, authorizationNonce));
        assertEq(vault.getDepositCount(), 1);
        assertEq(token.balanceOf(address(vault)), 100);
        assertEq(token.balanceOf(sender), 900);
    }
}
