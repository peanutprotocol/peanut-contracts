// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/V4/PeanutV4.sol";
import "../../src/util/ERC20Mock.sol";
import "../../src/util/SampleSCW.sol";

contract PeanutV4Test is Test {
    PeanutV4 public peanutV4;
    ERC20Mock public testToken;

    address public constant PUBKEY20 = address(0xaBC5211D86a01c2dD50797ba7B5b32e3C1167F9f);

    address public constant SAMPLE_ADDRESS = address(0x8fd379246834eac74B8419FfdA202CF8051F7A03);
    bytes32 public constant SAMPLE_PRIVKEY = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

    address public constant SAMPLE_ADDRESS_2 = address(0x88f9B82462f6C4bf4a0Fb15e5c3971559a316e7f);
    bytes32 public constant SAMPLE_PRIVKEY_2 = 0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb;

    // For EIP-3009 testing
    // keccak256("ReceiveWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)")
    bytes32 public constant RECEIVE_WITH_AUTHORIZATION_TYPEHASH =
        0xd099cc98ef71107a616c4f0f941f04c322d8e254fe26b3c6668db87aae413de8;
    bytes32 public DOMAIN_SEPARATOR = 0xcaa2ce1a5703ccbe253a34eb3166df60a705c561b44b192061e28f2a985be2ca;

    function setUp() public {
        console.log("Setting up test");
        testToken = new ERC20Mock();
        peanutV4 = new PeanutV4(address(0));
    }

    function testMakeDepostERC20WithAuthorization() public {
        testToken.mint(SAMPLE_ADDRESS, 1000);

        uint256 amount = 1000;
        bytes32 _nonce = bytes32(0); // any random value
        bytes32 authorizationNonce = keccak256(abi.encodePacked(PUBKEY20, _nonce));

        bytes memory typeHashAndData = abi.encode(
            RECEIVE_WITH_AUTHORIZATION_TYPEHASH,
            SAMPLE_ADDRESS, // the spender & peanut depositor address
            address(peanutV4), // receiver of the tokens
            amount,
            block.timestamp - 1, // validUntil
            block.timestamp + 1, // validBefore
            authorizationNonce
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, keccak256(typeHashAndData)));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(SAMPLE_PRIVKEY), digest);

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

    function _makeDeposit(address depositor) internal returns (uint256 depositIndex) {
        // Make a deposit
        testToken.mint(depositor, 1000);
        uint256 amount = 100;
        vm.prank(depositor);
        testToken.approve(address(peanutV4), amount);
        vm.prank(depositor);
        depositIndex = peanutV4.makeDeposit(address(testToken), 1, amount, 0, PUBKEY20);
    }

    function _calculateDigest(uint256 depositIndex) internal view returns (bytes32 digest) {
        bytes32 hashedReclaimRequest = keccak256(abi.encode(peanutV4.GASLESS_RECLAIM_TYPEHASH(), depositIndex));
        // Prepare data for the withdrawal
        digest = keccak256(abi.encodePacked("\x19\x01", peanutV4.DOMAIN_SEPARATOR(), hashedReclaimRequest));
    }

    function _withdrawDepositSenderGaslessEOA(
        uint256 depositIndex,
        address depositorAddress,
        bytes32 privateKey,
        string memory expectRevert
    ) internal {
        bytes32 digest = _calculateDigest(depositIndex);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(privateKey), digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        PeanutV4.GaslessReclaim memory reclaimRequest = PeanutV4.GaslessReclaim(depositIndex);

        if (bytes(expectRevert).length > 0) {
            vm.expectRevert(bytes(expectRevert));
        }

        peanutV4.withdrawDepositSenderGasless(reclaimRequest, depositorAddress, signature);
    }

    function testWithdrawDepositSenderGaslessEOA() public {
        // Make 2 deposits
        uint256 depositIndex1 = _makeDeposit(SAMPLE_ADDRESS);
        uint256 depositIndex2 = _makeDeposit(SAMPLE_ADDRESS);

        // Test a successful withdrawal of the second deposit
        _withdrawDepositSenderGaslessEOA(depositIndex2, SAMPLE_ADDRESS, SAMPLE_PRIVKEY, "");

        // depositIndex2 has already been withdrawn
        _withdrawDepositSenderGaslessEOA(depositIndex2, SAMPLE_ADDRESS, SAMPLE_PRIVKEY, "DEPOSIT ALREADY WITHDRAWN");

        // Correct depositor address, but wrong private key.
        // Private key and the provied address don't match.
        _withdrawDepositSenderGaslessEOA(depositIndex1, SAMPLE_ADDRESS, SAMPLE_PRIVKEY_2, "INVALID SIGNATURE");

        // Provided address and private key do match, but they are wrong.
        _withdrawDepositSenderGaslessEOA(depositIndex1, SAMPLE_ADDRESS_2, SAMPLE_PRIVKEY_2, "NOT THE SENDER");

        // Make one more from another address
        uint256 depositIndex3 = _makeDeposit(SAMPLE_ADDRESS_2);

        // Make sure that we can't withdraw it with the keys from another deposit
        _withdrawDepositSenderGaslessEOA(depositIndex3, SAMPLE_ADDRESS, SAMPLE_PRIVKEY, "NOT THE SENDER");

        // Withdraw both
        _withdrawDepositSenderGaslessEOA(depositIndex1, SAMPLE_ADDRESS, SAMPLE_PRIVKEY, "");
        _withdrawDepositSenderGaslessEOA(depositIndex3, SAMPLE_ADDRESS_2, SAMPLE_PRIVKEY_2, "");
    }

    // Test that smart contract wallets are able to withdraw gsalessly too
    function testWithdrawDepositSenderGaslessSCW() public {
        // Make a deposit
        SampleWallet scwallet = new SampleWallet();
        uint256 depositIndex = _makeDeposit(address(scwallet));

        bytes32 digest = _calculateDigest(depositIndex);

        PeanutV4.GaslessReclaim memory reclaimRequest = PeanutV4.GaslessReclaim(depositIndex);

        // Submit a wrong signature
        vm.expectRevert("INVALID SIGNATURE");
        peanutV4.withdrawDepositSenderGasless(
            reclaimRequest, address(scwallet), bytes("LOL THIS IS DEFINITELY NOT THE SIGNATURE")
        );

        // Try to withdraw with an EOA
        _withdrawDepositSenderGaslessEOA(depositIndex, SAMPLE_ADDRESS, SAMPLE_PRIVKEY, "NOT THE SENDER");

        // Withdraw!
        peanutV4.withdrawDepositSenderGasless(
            reclaimRequest,
            address(scwallet),
            // In our sample SCW the digest will be the right signature
            abi.encodePacked(digest)
        );
    }
}
