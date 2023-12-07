// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Super simple smart contract wallet that implements EIP-1271
// Code taken from https://eips.ethereum.org/EIPS/eip-1271
contract SampleWallet {
    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;

    /**
     * @dev Should return whether the signature provided is valid for the provided hash
     * @param _hash      Hash of the data to be signed
     * @param _signature Signature byte array associated with _hash
     *
     * MUST return the bytes4 magic value 0x1626ba7e when function passes.
     * MUST NOT modify state (using STATICCALL for solc < 0.5, view modifier for solc > 0.5)
     * MUST allow external calls
     */
    function isValidSignature(bytes32 _hash, bytes memory _signature) public pure returns (bytes4 magicValue) {
        // Simple verification algorithm that returns success if
        // the signature is the same as the hash.

        // Success
        if (bytes32(_signature) == _hash) return MAGICVALUE;

        // Failure
        return bytes4(0);
    }
}
