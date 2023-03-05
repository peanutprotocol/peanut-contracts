/* Module to deal with asymmetric encryption for Peanut protocol.
    Flow:
    1. Send:
        1. new key pair generated
        2. public key converted to ethereum address
        3. ethereum address saved on blockchain protecting deposit
        4. private key sent through link
    2. Receive:
        1. private key received
        2. Sign message with private key
        3. Submit signature to blockchain
        4. Verify signature on blockchain with ecrecover
        5. If signature is valid, withdraw deposit

    Optional: since private key is long, make deterministic function that maps private key to a shorter key and vice versa
*/

var ethers = require('ethers');
var crypto = require('crypto');
var EC = require('elliptic').ec


function generateKeys() {
    /* generates a new key pair and returns the address, private key, and public key
        alternatively, could use ethers.Wallet.createRandom()
        https://docs.ethers.org/v5/api/signer/#Wallet-createRandom
    */

    var id = crypto.randomBytes(32).toString('hex');
    var privateKey = "0x" + id;
    var wallet = new ethers.Wallet(privateKey);
    var publicKey = wallet.publicKey;

    return { address: wallet.address, privateKey: privateKey, publicKey: publicKey };
}

async function signMessageWithPrivatekey(message, privateKey) {
    /* signs a message with a private key and returns the signature
        THIS SHOULD BE AN UNHASHED, UNPREFIXED MESSAGE
    */
    var signer = new ethers.Wallet(privateKey);
    return signer.signMessage(message);  // this calls ethers.utils.hashMessage and prefixes the hash
}

function verifySignature(message, signature, address) {
    /* verifies a signature with a public key and returns true if valid */
    const messageSigner = ethers.utils.verifyMessage(message, signature);
    return messageSigner == address;
}

function generateKeysFromString(string) {
    /* generates a key pair from an arbitrary lengthk string */
    var id = crypto.createHash('sha256').update(string).digest('hex');
    var privateKey = "0x" + id;
    var wallet = new ethers.Wallet(privateKey);
    var publicKey = wallet.publicKey;

    return { address: wallet.address, privateKey: privateKey, publicKey: publicKey };
}

function solidityHashAddress(address) {
    /* hashes an address to a 32 byte hex string */
    return ethers.utils.solidityKeccak256(["address"], [address]);
}



async function signString(string, privateKey) {
    /// 1. hash plain address - 2. hash of (prefix + hash)
    const stringHash = solidityHashAddress(string);
    const stringHashbinary = ethers.utils.arrayify(stringHash);

    // this adds eth msg prefix, then hashes it, then signs it:
    var signature = await signMessageWithPrivatekey(stringHashbinary, privateKey);
}
// tests

async function functionTests() {
    // var keys = generateKeys();
    // console.log("Keys: ", keys);
    // var message = "hello world";
    // var signature = await signMessageWithPrivatekey(message, keys.privateKey);
    // console.log("Signature: ", signature);
    // var valid = verifySignature(message, signature, keys.address);
    // console.log("Valid: ", valid);
    // var address = ethers.utils.computeAddress(keys.publicKey);
    // console.log("Address from Public Key: ", address);
    // console.log("Address from Public Key == Address: ", address == keys.address);
    // console.log("\n\n");


    // var keys2 = generateKeyFromString("hello world!");
    // console.log(keys2);

    // var message = "I love Peanuts!";
    // var messageBytes = ethers.utils.toUtf8Bytes(message);
    // var messageHash = ethers.utils.keccak256(messageBytes);

    // var prefixedMessageHash = ethers.utils.hashMessage(message); // has message prefix

    // console.log("Message: ", message);
    // console.log("Message Bytes: ", messageBytes);
    // console.log("Message Hash: ", messageHash);
    // console.log("Prefixed Message Hash: ", prefixedMessageHash);

    // var signature2 = await signMessageWithPrivatekey(messageHash, keys2.privateKey);
    // console.log("Signed message hash: ", signature2);

    // var valid2 = verifySignature(message, signature2, keys2.address);
    // console.log("Valid from string: ", valid2);


    // ...

    let message = "I love Peanuts!";
    let privateKey = "" // redacted, get from env
    var wallet = new ethers.Wallet(privateKey);
    console.log("Address: ", wallet.address);
    console.log(wallet);
    let messageHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(message));
    let messageHashWPrefix = ethers.utils.hashMessage(message);
    console.log(messageHashWPrefix)
    let signature1 = await signMessageWithPrivatekey(message, privateKey);
    let signature2 = await signMessageWithPrivatekey(messageHash, privateKey);
    let signature3 = await signMessageWithPrivatekey(messageHashWPrefix, privateKey);

    // etherscan signature: 0x9c46b90aa5ee3aa032f92cb2e6122d63902bce5f5c1ed95f5cd53e13d68c07273a84e2ba226dbf5d06cbfb9675be7907ee61bcdf43a18bb7deebbe89a0ac01521c
    // same as signature 1

    console.log("Signature 1: ", signature1);
    console.log("Signature 2: ", signature2);
    console.log("Signature 3: ", signature3);


}

// functionTests();


async function contractTests() {
    // test instance of contract

    // create calldata for makeDeposit function
    // params:
    /**
     * @notice Function to make a deposit
     * @dev For token deposits, allowance must be set before calling this function
     * @param _tokenAddress address of the token being sent. 0x0 for eth
     * @param _contractType uint8 for the type of contract being sent. 0 for eth, 1 for erc20, 2 for erc721, 3 for erc1155
     * @param _amount uint256 of the amount of tokens being sent (if erc20)
     * @param _tokenId uint256 of the id of the token being sent if erc721 or erc1155
     * @param _pubKey20 last 20 bytes of the public key of the deposit signer
     * @return uint256 index of the deposit
     */

    // create 0x0 token address
    var tokenAddress = ethers.constants.AddressZero;
    var contractType = 0;
    // 1 eth amount
    var amount = ethers.utils.parseEther("1");
    var tokenId = 0;

    // generate key pair
    var keys = generateKeysFromString("hello world");
    // eth address is the last 20 bytes of the hash of the public key
    var pubKeyHash = ethers.utils.keccak256(keys.publicKey);
    var pubKey20 = pubKeyHash.slice(-40);
    console.log(keys);
    console.log(pubKeyHash);
    console.log(pubKey20);

    console.log("token address: ", tokenAddress);
    console.log("contract type: ", contractType);
    console.log("amount: ", amount);
    console.log("token id: ", tokenId);
    console.log("pub key: ", pubKey20);
    console.log("pub key address: ", keys.address);


    // // create calldata
    // provider = new ethers.providers.JsonRpcProvider("https://mainnet.infura.io/v3/..."); // redacted, get from env
    // contract = new ethers.Contract(contractAddress, abi, provider);
    // var calldata = contract.interface.encodeFunctionData("makeDeposit", [tokenAddress, contractType, amount, tokenId, pubKey20]);
    console.log("\n\n");

    // create call data for withdrawDeposit function
    // params:
    /**
     * @notice Function to withdraw a deposit. Withdraws the deposit to the recipient address.
     * @dev The hash of the receiver address should be prefixed with "\x19Ethereum Signed Message:\n32"
     * @dev The signature should be signed with the private key corresponding to the public key stored in the deposit
     * @dev We don't check the unhashed address for security reasons. It's preferable to sign a hash of the address.
     * @param _index uint256 index of the deposit
     * @param _recipientAddress address of the recipient
     * @param _recipientAddressHash bytes32 hash of the recipient address
     * @param _signature bytes signature of the recipient address (65 bytes)
     * @return bool true if successful
     */

    // create deposit index
    var index = 0;
    // create recipient address
    var recipientAddress = "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4";
    console.log("recipient address: ", recipientAddress);
    console.log("recipient address signature: ", signString(recipientAddress, keys.privateKey));
    // create recipient address hash
    /// 1. hash plain address - 2. hash of (prefix + hash)
    var recipientAddressHash1 = solidityHashAddress(recipientAddress);
    const recipientAddressHash1binary = ethers.utils.arrayify(recipientAddressHash1)

    var recipientAddressHash2 = ethers.utils.hashMessage(recipientAddress);
    var recipientAddressHash2bin = ethers.utils.hashMessage(recipientAddressHash1binary);
    var recipientAddressHash3 = _hashMessage(recipientAddress);
    console.log("** plain recipient address: ", recipientAddress);
    console.log("** recipient address hash 1 (no prefix): ", recipientAddressHash1);
    console.log("** recipient address hash 1 (no prefix) binary: ", recipientAddressHash1binary);
    console.log("** recipient address hash 2 (with prefix): ", recipientAddressHash2);
    console.log("** recipient address hash 2 binary (with prefix): ", recipientAddressHash2);
    console.log("** recipient address hash 3 (with prefix): ", recipientAddressHash3);
    // create signature (sign hash of (prefix + hash))
    var signature = await signMessageWithPrivatekey(recipientAddressHash1, keys.privateKey);

    /* process:
        1. recipient address
        2. hash plain address: hashed address
        3. hash of (prefix + hash)
        4. sign 3)

        in smart contract receive:
        1. plain address
        2. signature
        3. hash of (prefix + hash)

    */

    // verify signature
    var valid = verifySignature(recipientAddressHash1, signature, keys.address);

    console.log("index: ", index);
    console.log("recipient address: ", recipientAddress);
    console.log("recipient address hash 1 (no prefix): ", recipientAddressHash1);
    console.log("recipient address hash 2 (with prefix): ", recipientAddressHash2);
    console.log("signature: ", signature);
    console.log("recipient address signature w/ function: ", signString(recipientAddress, keys.privateKey));
    console.log("signer address: ", keys.address)
    console.log("valid: ", valid);


}

contractTests();


function _hashMessage(message) {
    const messagePrefix = "\x19Ethereum Signed Message:\n";
    const toUtf8Bytes = ethers.utils.toUtf8Bytes;
    const keccak256 = ethers.utils.keccak256;
    const concat = ethers.utils.concat;
    if (typeof (message) === "string") { message = toUtf8Bytes(message) }
    // console.log(message)
    // var con = concat([
    //     toUtf8Bytes(messagePrefix),
    //     toUtf8Bytes(String(message.length)),
    //     message
    // ]);
    // // turn to hex string
    // var hex = ethers.utils.hexlify(con);
    // console.log(hex);
    // console.log(keccak256(hex));
    return keccak256(concat([
        toUtf8Bytes(messagePrefix),
        toUtf8Bytes(String(message.length)),
        message
    ]));
}
