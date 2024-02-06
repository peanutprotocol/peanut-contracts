// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/V4/PeanutV4.3.sol";

contract PeanutV4MFATest is Test {
    PeanutV4 public peanutV4;

    // a dummy private/public keypair to test withdrawals
    address public constant SAMPLE_ADDRESS = address(0x8fd379246834eac74B8419FfdA202CF8051F7A03);
    bytes32 public constant SAMPLE_PRIVKEY = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

    function setUp() public {
        peanutV4 = new PeanutV4(address(0));
    }

    function testMFADeposit() public {
      uint256 depositIndex = peanutV4.makeSelflessMFADeposit{value: 1}(
        0x0000000000000000000000000000000000000000,
        0,
        1,
        0,
        SAMPLE_ADDRESS,
        0x0000000000000000000000000000000000001234);

        bytes32 digest = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    peanutV4.PEANUT_SALT(),
                    block.chainid,
                    address(peanutV4),
                    depositIndex,
                    address(this), // recipient
                    peanutV4.ANYONE_WITHDRAWAL_MODE()
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(SAMPLE_PRIVKEY), digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Withdrawing without authorization, so should fail
        vm.expectRevert("REQUIRES AUTHORIZATION");
        peanutV4.withdrawDeposit(depositIndex, address(this), signature);

        // Withdrawing with incorrect authorizattion signature
        vm.expectRevert("WRONG MFA SIGNATURE");
        peanutV4.withdrawMFADeposit(depositIndex, address(this), signature, signature);

        // Authorization is correct! Withdrawal has to be successful!
        bytes memory authorization = hex"41caae599d693a31ea45aab95c8d166e9709cb450f1c76a2b06306ee61cb28b37ed0cad0d47d055580ce204ac9973b671a0970d02f9ee6572a9234f3130707321c";
        peanutV4.withdrawMFADeposit(depositIndex, address(this), signature, authorization);
    }

    receive () payable external {}
}