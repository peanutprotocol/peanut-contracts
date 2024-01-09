// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../../src/V4/PeanutV4.2.sol";
import "../../src/V4/PeanutRouter.sol";
import "../../src/util/SquidMock.sol";
import "../../src/util/ERC20Mock.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


contract PeanutV4RouterTest is Test {
    PeanutV4 public peanutV4;
    SquidMock public squidMock;
    PeanutV4Router public peanutV4Router;
    ERC20Mock public testToken;

    address public constant SAMPLE_ADDRESS = address(0x8fd379246834eac74B8419FfdA202CF8051F7A03);
    bytes32 public constant SAMPLE_PRIVKEY = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;
    bytes4 SQUID_MOCK_FUNCTION_SIGNATURE = bytes4(keccak256("superPowerfulBridge(address,uint256)"));

    function setUp() public {
        testToken = new ERC20Mock();
        peanutV4 = new PeanutV4(address(0));
        squidMock = new SquidMock();
        peanutV4Router = new PeanutV4Router(address(squidMock));
    }

    function _signPeanutWithdrawal(uint256 depositIndex, address recipientAddress, bytes32 privateKey) internal view returns (bytes memory signature) {
        bytes32 digest = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    peanutV4.PEANUT_SALT(),
                    block.chainid,
                    address(peanutV4),
                    depositIndex,
                    recipientAddress,
                    peanutV4.RECIPIENT_WITHDRAWAL_MODE()
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(privateKey), digest);
        signature = abi.encodePacked(r, s, v);
    }

    function _signPeanutRouting(uint256 depositIndex, uint256 squidFee, uint256 peanutFee, bytes memory squidData, bytes32 privateKey) internal view returns (bytes memory signature) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                bytes2(0x1900),
                address(peanutV4Router),
                block.chainid,
                address(peanutV4),
                depositIndex,
                address(squidMock),
                squidFee,
                peanutFee,
                squidData
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(privateKey), digest);
        signature = abi.encodePacked(r, s, v);
    }

    function testWithdrawERC20AndBridge(
        uint128 amountDeposited, // uint128 to prevent total supply overflow
        uint96 requiredSquidFee, // uint96 to not run out of the default fuceted ETH amount
        uint256 requiredPeanutFee
    ) public {
        vm.assume(requiredPeanutFee < amountDeposited);

        testToken.mint(address(this), amountDeposited);
        testToken.approve(address(peanutV4), amountDeposited);
        uint256 depositIndex = peanutV4.makeDeposit(address(testToken), 1, amountDeposited, 0, SAMPLE_ADDRESS);
        
        bytes memory withdrawalSignature = _signPeanutWithdrawal(
            depositIndex,
            address(peanutV4Router),
            SAMPLE_PRIVKEY
        );

        bytes memory squidData = abi.encodePacked(
            SQUID_MOCK_FUNCTION_SIGNATURE,
            abi.encode(  // args have to be 32-bytes padded
                address(testToken),
                amountDeposited - requiredPeanutFee  // testToken amount to be transferred to the squid mock
            )
        );

        bytes memory routingSignature = _signPeanutRouting(
            depositIndex,
            requiredSquidFee,
            requiredPeanutFee,
            squidData,
            SAMPLE_PRIVKEY
        );

        // Relayer attempts to charge a higher peanut fee
        vm.expectRevert("WRONG ROUTING SIGNER");
        peanutV4Router.withdrawAndBridge{value: requiredSquidFee}(
            address(peanutV4),
            depositIndex,
            withdrawalSignature,
            requiredSquidFee,
            requiredPeanutFee + 10,
            squidData,
            routingSignature
        );

         if (requiredSquidFee > 0) {
            // Relayer attempts to pay a lower squid fee
            vm.expectRevert("msg.value MUST BE THE SQUID FEE");
            peanutV4Router.withdrawAndBridge{value: requiredSquidFee - 1}(
                address(peanutV4),
                depositIndex,
                withdrawalSignature,
                requiredSquidFee,
                requiredPeanutFee,
                squidData,
                routingSignature
            );

            // Relayer attempts to pay a lower squid fee and also modifies the arguments
            vm.expectRevert("WRONG ROUTING SIGNER");
            peanutV4Router.withdrawAndBridge{value: requiredSquidFee - 1}(
                address(peanutV4),
                depositIndex,
                withdrawalSignature,
                requiredSquidFee - 1,
                requiredPeanutFee,
                squidData,
                routingSignature
            );
        }

        // Someone tries to front-run with malicious squidData
        vm.expectRevert("WRONG ROUTING SIGNER");
        peanutV4Router.withdrawAndBridge{value: requiredSquidFee}(
            address(peanutV4),
            depositIndex,
            withdrawalSignature,
            requiredSquidFee,
            requiredPeanutFee,
            bytes("BAD BAD BAD BAD"),
            routingSignature
        );

        // Withdraw and bridge! Withdraw and bridge! Withdraw and bridge!
        peanutV4Router.withdrawAndBridge{value: requiredSquidFee}(
            address(peanutV4),
            depositIndex,
            withdrawalSignature,
            requiredSquidFee,
            requiredPeanutFee,
            squidData,
            routingSignature
        );

        require(testToken.balanceOf(address(squidMock)) == amountDeposited - requiredPeanutFee, "TOKENS WERE NOT TRANSFERRED TO SQUID");
        require(testToken.balanceOf(address(peanutV4Router)) == requiredPeanutFee, "PEANUT FEE WAS NOT COLLECTED");
        require(address(squidMock).balance == requiredSquidFee, "FEE WAS NOT PAID TO SQUID");
    }

    function testWithdrawETHAndBridge(
        uint96 amountDeposited,
        uint96 requiredSquidFee,
        uint96 requiredPeanutFee
    ) public {
        // prevent out of funds problems
        vm.assume(uint256(amountDeposited) + uint256(requiredSquidFee) + uint256(requiredPeanutFee) < 2 ** 96);
        vm.assume(amountDeposited > requiredPeanutFee);

        uint256 depositIndex = peanutV4.makeDeposit{value: amountDeposited}(address(0), 0, 0, 0, SAMPLE_ADDRESS);
        
        bytes memory withdrawalSignature = _signPeanutWithdrawal(
            depositIndex,
            address(peanutV4Router),
            SAMPLE_PRIVKEY
        );

        // uint256 requiredSquidFee = 100; // 100 wei
        // uint256 requiredPeanutFee = 130; // 130 wei

        bytes memory squidData = abi.encodePacked(
            SQUID_MOCK_FUNCTION_SIGNATURE,
            abi.encode(  // args have to be 32-bytes padded
                address(0),
                amountDeposited + requiredSquidFee - requiredPeanutFee // ETH amount to be transferred to the squid mock
            )
        );

        bytes memory routingSignature = _signPeanutRouting(
            depositIndex,
            requiredSquidFee,
            requiredPeanutFee,
            squidData,
            SAMPLE_PRIVKEY
        );

        // Withdraw and bridge! Withdraw and bridge! Withdraw and bridge!
        peanutV4Router.withdrawAndBridge{value: requiredSquidFee}(
            address(peanutV4),
            depositIndex,
            withdrawalSignature,
            requiredSquidFee,
            requiredPeanutFee,
            squidData,
            routingSignature
        );

        require(address(squidMock).balance == amountDeposited + requiredSquidFee - requiredPeanutFee, "AMOUNT OR FEE WAS NOT PAID TO SQUID");
        require(address(peanutV4Router).balance == requiredPeanutFee, "PEANUT FEE WAS NOT COLLECTED");
    }

    function testWithdrawFee(
        uint96 collectedEth,
        uint128 collectedTokens,
        uint96 ethToWithdraw,
        uint128 tokensToWithdraw
    ) public {
        vm.assume(ethToWithdraw <= collectedEth);
        vm.assume(tokensToWithdraw <= collectedTokens);

        // Pretend that there were some transfers and some fee was collected in the peanut router
        testToken.mint(address(this), collectedTokens);
        testToken.transfer(address(peanutV4Router), collectedTokens);
        payable(address(peanutV4Router)).transfer(collectedEth);

        // Non-owner can't withdraw
        vm.prank(SAMPLE_ADDRESS);
        vm.expectRevert("Ownable: caller is not the owner");
        peanutV4Router.withdrawFees(address(0), SAMPLE_ADDRESS, ethToWithdraw);

        peanutV4Router.withdrawFees(address(0), SAMPLE_ADDRESS, ethToWithdraw);
        require(address(SAMPLE_ADDRESS).balance == ethToWithdraw, "RECEIVED WRONG AMOUNT OF ETH");

        peanutV4Router.withdrawFees(address(testToken), SAMPLE_ADDRESS, tokensToWithdraw);
        require(testToken.balanceOf(SAMPLE_ADDRESS) == tokensToWithdraw, "RECEIVED WRONG AMOUNT OF testToken");
    }
}
