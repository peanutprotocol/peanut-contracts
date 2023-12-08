// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/V4/PeanutV4.sol";
import "../../src/util/ERC20Mock.sol";

contract PeanutV4Test is Test {
    PeanutV4 public peanutV4;
    ERC20Mock public testToken;

    // a dummy private/public keypair to test withdrawals
    address public constant PUBKEY20 =
        address(0xaBC5211D86a01c2dD50797ba7B5b32e3C1167F9f);

    address public constant SAMPLE_ADDRESS =
        address(0x8fd379246834eac74B8419FfdA202CF8051F7A03);
    bytes32 public constant SAMPLE_PRIVKEY =
        0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

    // For EIP-3009 testing
    // keccak256("ReceiveWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)")
    bytes32 public constant RECEIVE_WITH_AUTHORIZATION_TYPEHASH =
        0xd099cc98ef71107a616c4f0f941f04c322d8e254fe26b3c6668db87aae413de8;
    bytes32 public DOMAIN_SEPARATOR =
        0xcaa2ce1a5703ccbe253a34eb3166df60a705c561b44b192061e28f2a985be2ca;

    function setUp() public {
        console.log("Setting up test");
        testToken = new ERC20Mock();
        peanutV4 = new PeanutV4(address(0));
    }

    function testMakeDepostERC20WithAuthorization() public {
        testToken.mint(SAMPLE_ADDRESS, 1000);

        uint256 amount = 1000;
        bytes32 _nonce = bytes32(0); // any random value
        bytes32 authorizationNonce = keccak256(
            abi.encodePacked(PUBKEY20, _nonce)
        );

        bytes memory typeHashAndData = abi.encode(
            RECEIVE_WITH_AUTHORIZATION_TYPEHASH,
            SAMPLE_ADDRESS, // the spender & peanut depositor address
            address(peanutV4), // receiver of the tokens
            amount,
            block.timestamp - 1, // validUntil
            block.timestamp + 1, // validBefore
            authorizationNonce
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(typeHashAndData)
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            uint256(SAMPLE_PRIVKEY),
            digest
        );

        uint256 depositIndex = peanutV4.makeDepositWithAuthorization(
            address(testToken),
            SAMPLE_ADDRESS, // who makes the deposit
            amount,
            PUBKEY20,
            _nonce,
            block.timestamp - 1, // validUntil
            block.timestamp + 1, // validBefore
            v,
            r,
            s
        );

        assertEq(depositIndex, 0, "Deposit failed");
        assertEq(peanutV4.getDepositCount(), 1, "Deposit count mismatch");
    }
}
