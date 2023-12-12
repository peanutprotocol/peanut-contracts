// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

//////////////////////////////////////////////////////////////////////////////////////
// @title   Peanut Protocol
// @notice  This contract is used to send non front-runnable link payments. These can
//          be erc20, erc721, erc1155 or just plain eth. The recipient address is arbitrary.
//          Links use asymmetric ECDSA encryption by default to be secure & enable trustless,
//          gasless claiming.
//          more at: https://peanut.to
// @version 0.4.2
// @author  Squirrel Labs
//////////////////////////////////////////////////////////////////////////////////////
//⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
//                         ⠀⠀⢀⣀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣶⣶⣦⣌⠙⠋⢡⣴⣶⡄⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⣿⣿⣿⡿⢋⣠⣶⣶⡌⠻⣿⠟⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⡆⠸⠟⢁⣴⣿⣿⣿⣿⣿⡦⠉⣴⡇⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣾⣿⠟⠀⠰⣿⣿⣿⣿⣿⣿⠟⣠⡄⠹⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡀⢸⡿⢋⣤⣿⣄⠙⣿⣿⡿⠟⣡⣾⣿⣿⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⣠⣴⣾⠿⠀⢠⣾⣿⣿⣿⣦⠈⠉⢠⣾⣿⣿⣿⠏⠀⠀⠀
// ⠀⠀⠀⠀⣀⣤⣦⣄⠙⠋⣠⣴⣿⣿⣿⣿⠿⠛⢁⣴⣦⡄⠙⠛⠋⠁⠀⠀⠀⠀
// ⠀⠀⢀⣾⣿⣿⠟⢁⣴⣦⡈⠻⣿⣿⡿⠁⡀⠚⠛⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠘⣿⠟⢁⣴⣿⣿⣿⣿⣦⡈⠛⢁⣼⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⢰⡦⠀⢴⣿⣿⣿⣿⣿⣿⣿⠟⢀⠘⠿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠘⢀⣶⡀⠻⣿⣿⣿⣿⡿⠋⣠⣿⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⢿⣿⣿⣦⡈⠻⣿⠟⢁⣼⣿⣿⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠈⠻⣿⣿⣿⠖⢀⠐⠿⠟⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠈⠉⠁⠀⠀⠀⠀⠀
//
//////////////////////////////////////////////////////////////////////////////////////

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {IL2ECO} from "../util/IL2ECO.sol";
import {IEIP3009} from "../util/IEIP3009.sol";

contract PeanutV4 is IERC721Receiver, IERC1155Receiver, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Deposit {
        address pubKey20; // (20 bytes) last 20 bytes of the hash of the public key for the deposit
        uint256 amount; // (32 bytes) amount of the asset being sent
        ///// tokenAddress, contractType, tokenId, claimed & timestamp are stored in a single 32 byte word
        address tokenAddress; // (20 bytes) address of the asset being sent. 0x0 for eth
        uint8 contractType; // (1 byte) 0 for eth, 1 for erc20, 2 for erc721, 3 for erc1155 4 for ECO-like rebasing erc20
        bool claimed; // (1 byte) has this deposit been claimed
        uint40 timestamp; // ( 5 bytes) timestamp of the deposit
        /////
        uint256 tokenId; // (32 bytes) id of the token being sent (if erc721 or erc1155)
        address senderAddress; // (20 bytes) address of the sender
    }

    // We may include this hash in peanut-specific signatures to make sure
    // that the message signed by the user has effects only in peanut contracts.
    bytes32 PEANUT_SALT = 0x70adbbeba9d4f0c82e28dd574f15466f75df0543b65f24460fc445813b5d94e0; // keccak256("Konrad makes tokens go woosh tadam");

    bytes32 ANYONE_WITHDRAWAL_MODE = 0x0000000000000000000000000000000000000000000000000000000000000000; // default. Any address can trigger the withdrawal function
    bytes32 RECIPIENT_WITHDRAWAL_MODE = 0x2bb5bef2b248d3edba501ad918c3ab524cce2aea54d4c914414e1c4401dc4ff4; // keccak256("only recipient") - only the signed recipient can trigger the withdrawal function

    bytes32 public DOMAIN_SEPARATOR; // initialized in the constructor

    bytes32 public EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    bytes32 public GASLESS_RECLAIM_TYPEHASH = keccak256("GaslessReclaim(uint256 depositIndex)");

    struct GaslessReclaim {
        uint256 depositIndex;
    }

    Deposit[] public deposits; // array of deposits
    address public ecoAddress; // address of the ECO token

    // events
    event DepositEvent(
        uint256 indexed _index, uint8 indexed _contractType, uint256 _amount, address indexed _senderAddress
    );
    event WithdrawEvent(
        uint256 indexed _index, uint8 indexed _contractType, uint256 _amount, address indexed _recipientAddress
    );
    event MessageEvent(string message);

    // constructor. Accepts ECO token address to prohibit ECO usage in normal
    // ERC20 deposits.
    // Initializes DOMAIN_SEPARATOR.
    // Wishes you a nutty day.
    constructor(address _ecoAddress) {
        emit MessageEvent("Hello World, have a nutty day!");
        ecoAddress = _ecoAddress;
        DOMAIN_SEPARATOR = hash(
            EIP712Domain({name: "Peanut", version: "4.2", chainId: block.chainid, verifyingContract: address(this)})
        );
    }

    function hash(EIP712Domain memory eip712Domain) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes(eip712Domain.name)),
                keccak256(bytes(eip712Domain.version)),
                eip712Domain.chainId,
                eip712Domain.verifyingContract
            )
        );
    }

    function hash(GaslessReclaim memory reclaim) internal view returns (bytes32) {
        return keccak256(abi.encode(GASLESS_RECLAIM_TYPEHASH, reclaim.depositIndex));
    }

    /**
     * @notice Recover a EIP-712 signed gasless reclaim message
     * @param reclaim the reclaim request
     * @param signer the expected signer of the reclaim request
     * @param signature r-s-v if the signer is an EOA or any random bytes if the signer is a smart contract
     */
    function verifyGaslessReclaim(GaslessReclaim memory reclaim, address signer, bytes memory signature)
        internal
        view
    {
        // Note: we need to use `encodePacked` here instead of `encode`.
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, hash(reclaim)));
        // By using SignatureChecker we support both EOAs and smart contract wallets
        bool valid = SignatureChecker.isValidSignatureNow(signer, digest, signature);
        require(valid, "INVALID SIGNATURE");
    }

    /**
     * @notice supportsInterface function
     *     @dev ERC165 interface detection
     *     @param _interfaceId bytes4 the interface identifier, as specified in ERC-165
     *     @return bool true if the contract implements the interface specified in _interfaceId
     */
    function supportsInterface(bytes4 _interfaceId) external pure override returns (bool) {
        return _interfaceId == type(IERC165).interfaceId || _interfaceId == type(IERC721Receiver).interfaceId
            || _interfaceId == type(IERC1155Receiver).interfaceId;
    }

    function makeDeposit(
        address _tokenAddress,
        uint8 _contractType,
        uint256 _amount,
        uint256 _tokenId,
        address _pubKey20
    ) public payable nonReentrant returns (uint256) {
        return _makeDeposit(_tokenAddress, _contractType, _amount, _tokenId, _pubKey20, msg.sender);
    }

    function makeSelflessDeposit(
        address _tokenAddress,
        uint8 _contractType,
        uint256 _amount,
        uint256 _tokenId,
        address _pubKey20,
        address _onBehalfOf
    ) public payable nonReentrant returns (uint256) {
        return _makeDeposit(_tokenAddress, _contractType, _amount, _tokenId, _pubKey20, _onBehalfOf);
    }

    /**
     * @notice Function to make a deposit
     * @dev For token deposits, allowance must be set before calling this function
     * @param _tokenAddress address of the token being sent. 0x0 for eth
     * @param _contractType uint8 for the type of contract being sent. 0 for eth, 1 for erc20, 2 for erc721, 3 for erc1155, 4 for ECO-like rebasing erc20
     * @param _amount uint256 of the amount of tokens being sent (if erc20)
     * @param _tokenId uint256 of the id of the token being sent if erc721 or erc1155
     * @param _pubKey20 last 20 bytes of the public key of the deposit signer
     * @param _onBehalfOf who will be able to reclaim the link if the private key is lost
     * @return uint256 index of the deposit
     */
    function _makeDeposit(
        address _tokenAddress,
        uint8 _contractType,
        uint256 _amount,
        uint256 _tokenId,
        address _pubKey20,
        address _onBehalfOf
    ) internal returns (uint256) {
        // check that the contract type is valid
        require(_contractType < 5, "INVALID CONTRACT TYPE");

        // handle deposit types
        if (_contractType == 0) {
            // check that the amount sent is equal to the amount being deposited
            require(msg.value > 0, "NO ETH SENT");
            // override amount with msg.value
            _amount = msg.value;
        } else if (_contractType == 1) {
            // REMINDER: User must approve this contract to spend the tokens before calling this function
            // Unfortunately there's no way of doing this in just one transaction.
            // Wallet abstraction pls

            // If ECO is deposited as a normal ERC20 and then inflation is increased,
            // the recipient would get more tokens than what was deposited.
            require(_tokenAddress != ecoAddress, "ECO DEPOSITS MUST USE _contractType 4");

            IERC20 token = IERC20(_tokenAddress);

            // transfer the tokens to the contract
            token.safeTransferFrom(msg.sender, address(this), _amount);
        } else if (_contractType == 2) {
            // REMINDER: User must approve this contract to spend the tokens before calling this function.
            // alternatively, the user can call the safeTransferFrom function directly and append the appropriate calldata

            IERC721 token = IERC721(_tokenAddress);
            // require(token.ownerOf(_tokenId) == msg.sender, "Invalid token id");
            token.safeTransferFrom(msg.sender, address(this), _tokenId, "Internal transfer");
        } else if (_contractType == 3) {
            // REMINDER: User must approve this contract to spend the tokens before calling this function.
            // alternatively, the user can call the safeTransferFrom function directly and append the appropriate calldata

            IERC1155 token = IERC1155(_tokenAddress);
            token.safeTransferFrom(msg.sender, address(this), _tokenId, _amount, "Internal transfer");
        } else if (_contractType == 4) {
            // REMINDER: User must approve this contract to spend the tokens before calling this function
            IL2ECO token = IL2ECO(_tokenAddress);

            // transfer the tokens to the contract
            require(
                token.transferFrom(msg.sender, address(this), _amount), "TRANSFER FAILED. CHECK ALLOWANCE & BALANCE"
            );

            // calculate the rebase invariant amount to store in the deposits array
            _amount *= token.linearInflationMultiplier();
        }

        // create deposit
        deposits.push(
            Deposit({
                tokenAddress: _tokenAddress,
                contractType: _contractType,
                amount: _amount,
                tokenId: _tokenId,
                claimed: false,
                pubKey20: _pubKey20,
                senderAddress: _onBehalfOf,
                timestamp: uint40(block.timestamp)
            })
        );

        // emit the deposit event
        emit DepositEvent(deposits.length - 1, _contractType, _amount, _onBehalfOf);

        // return id of new deposit
        return deposits.length - 1;
    }

    /**
     * @notice Function to make a deposit with EIP-3009 authorization
     * @dev No need to pre-approve tokens!
     * @param _tokenAddress address of the token being sent
     * @param _from the depositor of the tokens
     * @param _amount uint256 of the amount of tokens being sent
     * @param _pubKey20 last 20 bytes of the public key of the deposit signer
     * @param _nonce a unique value
     * @param _validAfter deposit is valid only after this timestamp (in seconds)
     * @param _validBefore deposit is valid only before this timestamp (in seconds)
     * @param _v v of the signature
     * @param _r r of the signature
     * @param _s s of the signature
     * @return uint256 index of the deposit
     */
    function makeDepositWithAuthorization(
        address _tokenAddress,
        address _from,
        uint256 _amount,
        address _pubKey20,
        bytes32 _nonce,
        uint256 _validAfter,
        uint256 _validBefore,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public nonReentrant returns (uint256) {
        // If ECO is deposited as a normal ERC20 and then inflation is increased,
        // the recipient would get more tokens than what was deposited.
        require(_tokenAddress != ecoAddress, "ECO must be be deposited via makeDeposit with tokenType 4");

        // Recalculate the nonce.
        // If we don't include pubKey20 in the nonce, the link will be front-runnable
        bytes32 nonce = keccak256(abi.encodePacked(_pubKey20, _nonce));

        IEIP3009 token = IEIP3009(_tokenAddress);
        token.receiveWithAuthorization(
            _from,
            address(this), // to
            _amount,
            _validAfter,
            _validBefore,
            nonce,
            _v,
            _r,
            _s
        );

        // create deposit
        deposits.push(
            Deposit({
                tokenAddress: _tokenAddress,
                contractType: 1, // always ERC20
                amount: _amount,
                tokenId: 0, // not used for ERC20
                claimed: false,
                pubKey20: _pubKey20,
                senderAddress: _from,
                timestamp: uint40(block.timestamp)
            })
        );

        // emit the deposit event
        emit DepositEvent(deposits.length - 1, 1, _amount, _from);

        // return id of new deposit
        return deposits.length - 1;
    }

    /**
     * @notice Erc721 token receiver function
     * @dev These functions are called by the token contracts when a token is sent to this contract
     * @dev If calldata is "Internal transfer" then the token was sent by this contract and we don't need to do anything
     * @dev Otherwise, calldata needs a 20 byte pubkey20
     * @param _operator address operator requesting the transfer
     * @param _from address address which previously owned the token
     * @param _tokenId uint256 ID of the token being transferred
     * @param _data bytes data to send along with a safe transfer check (has to be 32 bytes)
     */
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data)
        external
        override
        returns (bytes4)
    {
        if (_operator == address(this)) {
            // if operator is this contract, nothing to do, return
            return this.onERC721Received.selector;
        } else if (_data.length != 32) {
            // if data is not 32 bytes, revert (don't want to accept and lock up tokens!)
            revert("INVALID CALLDATA");
        }

        // create deposit
        deposits.push(
            Deposit({
                tokenAddress: msg.sender,
                contractType: 2,
                amount: 1,
                tokenId: _tokenId,
                pubKey20: address(abi.decode(_data, (bytes20))),
                senderAddress: _from,
                timestamp: uint40(block.timestamp),
                claimed: false
            })
        );

        // emit the deposit event
        emit DepositEvent(deposits.length - 1, 2, 1, _from);

        // return correct bytes4
        return this.onERC721Received.selector;
    }

    /**
     * @notice Erc1155 token receiver function
     *     @dev These functions are called by the token contracts when a token is sent to this contract
     *     @dev If calldata is "Internal transfer" then the token was sent by this contract and we don't need to do anything
     *     @dev Otherwise, calldata needs 20 bytes pubKey20
     *     @param _operator address operator requesting the transfer
     *     @param _from address address which previously owned the token
     *     @param _tokenId uint256 ID of the token being transferred
     *     @param _value uint256 amount of tokens being transferred
     *     @param _data bytes data passed with the call
     */
    function onERC1155Received(address _operator, address _from, uint256 _tokenId, uint256 _value, bytes calldata _data)
        external
        override
        returns (bytes4)
    {
        if (_operator == address(this)) {
            return this.onERC1155Received.selector;
        } else if (_data.length != 32) {
            // if data is not 32 bytes, revert (don't want to accept and lock up tokens!)
            revert("INVALID CALLDATA");
        }

        deposits.push(
            Deposit({
                tokenAddress: msg.sender,
                contractType: 3,
                amount: _value,
                tokenId: _tokenId,
                pubKey20: address(abi.decode(_data, (bytes20))),
                senderAddress: _from,
                timestamp: uint40(block.timestamp),
                claimed: false
            })
        );

        // emit the deposit event
        emit DepositEvent(deposits.length - 1, 3, _value, _from);

        // return correct bytes4
        return this.onERC1155Received.selector;
    }

    /**
     * @notice Erc1155 token receiver function
     * @dev These functions are called by the token contracts when a set of tokens is sent to this contract
     * @dev If calldata is "Internal transfer" then the token was sent by this contract and we don't need to do anything
     * @param _operator address operator requesting the transfer
     * @param _from address address which previously owned the token
     * @param _ids uint256[] IDs of each token being transferred (order and length must match _values array)
     * @param _values uint256[] amount of each token being transferred (order and length must match _ids array)
     * @param _data bytes data forwarded from the caller
     * @dev _data needs to contain array of 32 byte pubKey20s (length must match _ids and _values arrays). Encode with abi.encode()
     */
    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external override returns (bytes4) {
        if (_operator == address(this)) {
            return this.onERC1155BatchReceived.selector;
        } else if (_data.length != (_ids.length * 32)) {
            // dont accept if data is not 32 bytes per token
            revert("INVALID CALLDATA");
        }

        for (uint256 i = 0; i < _ids.length; i++) {
            deposits.push(
                Deposit({
                    tokenAddress: msg.sender, // token address (not the address of transaction sender)
                    contractType: 3, // 3 is for ERC1155 (should be uint8)
                    amount: _values[i], // amount of this token
                    tokenId: _ids[i], // token id
                    pubKey20: address(bytes20(_data[i * 32:i * 32 + 20])),
                    senderAddress: _from,
                    timestamp: uint40(block.timestamp),
                    claimed: false
                })
            );

            // emit the deposit event
            emit DepositEvent(
                deposits.length - 1,
                3,
                _values[i], // amount of this token
                _from
            );
        }

        // return correct bytes4
        return this.onERC1155BatchReceived.selector;
    }

     /**
     * @notice Function to withdraw tokens. Can be called by anyone.
     * @return bool true if successful
     */
    function withdrawDeposit(
        uint256 _index,
        address _recipientAddress,
        bytes memory _signature
    ) external nonReentrant returns (bool) {
        return _withdrawDeposit(
            _index,
            _recipientAddress,
            ANYONE_WITHDRAWAL_MODE,
            _signature
        );
    }

    /**
     * @notice Function to withdraw tokens. Must be called by the recipient.
     *         This is useful for 
     * @return bool true if successful
     */
    function withdrawDepositAsRecipient(
        uint256 _index,
        address _recipientAddress,
        bytes memory _signature
    ) external nonReentrant returns (bool) {
        require(_recipientAddress == msg.sender, "NOT THE RECIPIENT");

        return _withdrawDeposit(
            _index,
            _recipientAddress,
            RECIPIENT_WITHDRAWAL_MODE,
            _signature
        );
    }

    /**
     * @notice Function to withdraw a deposit. Withdraws the deposit to the recipient address.
     * @dev _recipientAddressHash is hash("\x19Ethereum Signed Message:\n32" + hash(_recipientAddress))
     * @dev The signature should be signed with the private key corresponding to the public key stored in the deposit
     * @dev We don't check the unhashed address for security reasons. It's preferable to sign a hash of the address.
     * @param _index uint256 index of the deposit
     * @param _recipientAddress address of the recipient
     * @param _extraData extra data that has to be signed by the user
     * @param _signature bytes signature of the recipient address (65 bytes)
     * @return bool true if successful
     */
    function _withdrawDeposit(
        uint256 _index,
        address _recipientAddress,
        bytes32 _extraData,
        bytes memory _signature
    ) internal returns (bool) {
        // check that the deposit exists and that it isn't already withdrawn
        require(_index < deposits.length, "DEPOSIT INDEX DOES NOT EXIST");
        Deposit memory _deposit = deposits[_index];
        require(_deposit.claimed == false, "DEPOSIT ALREADY WITHDRAWN");

        // Compute the hash of the withdrawal message
        bytes32 _recipientAddressHash = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    PEANUT_SALT,
                    block.chainid,
                    address(this),
                    _index,
                    _recipientAddress,
                    _extraData
                )
            )
        );
        // check that the signer is the same as the one stored in the deposit
        address depositSigner = getSigner(_recipientAddressHash, _signature);
        require(depositSigner == _deposit.pubKey20, "WRONG SIGNATURE");

        // emit the withdraw event
        emit WithdrawEvent(_index, _deposit.contractType, _deposit.amount, _recipientAddress);

        // mark as claimed
        deposits[_index].claimed = true;

        // Deposit request is valid. Withdraw the deposit to the recipient address.
        if (_deposit.contractType == 0) {
            /// handle eth deposits
            (bool success,) = _recipientAddress.call{value: _deposit.amount}("");
            require(success, "Transfer failed");
        } else if (_deposit.contractType == 1) {
            /// handle erc20 deposits
            IERC20 token = IERC20(_deposit.tokenAddress);
            token.safeTransfer(_recipientAddress, _deposit.amount);
        } else if (_deposit.contractType == 2) {
            /// handle erc721 deposits
            IERC721 token = IERC721(_deposit.tokenAddress);
            token.safeTransferFrom(address(this), _recipientAddress, _deposit.tokenId);
        } else if (_deposit.contractType == 3) {
            /// handle erc1155 deposits
            IERC1155 token = IERC1155(_deposit.tokenAddress);
            token.safeTransferFrom(address(this), _recipientAddress, _deposit.tokenId, _deposit.amount, "");
        } else if (_deposit.contractType == 4) {
            /// handle rebasing erc20 deposits on l2
            IL2ECO token = IL2ECO(_deposit.tokenAddress);
            uint256 scaledAmount = _deposit.amount / token.linearInflationMultiplier();
            require(token.transfer(_deposit.senderAddress, scaledAmount), "TRANSFER FAILED");
        }

        return true;
    }

    /**
     * @notice Function to allow a sender to withdraw their deposit after 24 hours
     * @param _index uint256 index of the deposit
     * @param _senderAddress the address of the depositor
     * @return bool true if successful
     */
    function _withdrawDepositSender(uint256 _index, address _senderAddress) internal returns (bool) {
        // check that the deposit exists
        require(_index < deposits.length, "DEPOSIT INDEX DOES NOT EXIST");
        Deposit memory _deposit = deposits[_index];
        require(_deposit.claimed == false, "DEPOSIT ALREADY WITHDRAWN");
        // check that the sender is the one who made the deposit
        require(_deposit.senderAddress == _senderAddress, "NOT THE SENDER");

        // emit the withdraw event
        emit WithdrawEvent(_index, _deposit.contractType, _deposit.amount, _deposit.senderAddress);

        // Delete the deposit
        deposits[_index].claimed = true;

        if (_deposit.contractType == 0) {
            /// handle eth deposits
            payable(_deposit.senderAddress).transfer(_deposit.amount);
        } else if (_deposit.contractType == 1) {
            /// handle erc20 deposits
            IERC20 token = IERC20(_deposit.tokenAddress);
            token.safeTransfer(_deposit.senderAddress, _deposit.amount);
        } else if (_deposit.contractType == 2) {
            /// handle erc721 deposits
            IERC721 token = IERC721(_deposit.tokenAddress);
            token.safeTransferFrom(address(this), _deposit.senderAddress, _deposit.tokenId);
        } else if (_deposit.contractType == 3) {
            /// handle erc1155 deposits
            IERC1155 token = IERC1155(_deposit.tokenAddress);
            token.safeTransferFrom(address(this), _deposit.senderAddress, _deposit.tokenId, _deposit.amount, "");
        } else if (_deposit.contractType == 4) {
            /// handle rebasing erc20 deposits on l2
            IL2ECO token = IL2ECO(_deposit.tokenAddress);
            uint256 scaledAmount = _deposit.amount / token.linearInflationMultiplier();
            require(token.transfer(_deposit.senderAddress, scaledAmount), "TRANSFER FAILED");
        }

        return true;
    }

    function withdrawDepositSender(uint256 _index) external nonReentrant returns (bool) {
        return _withdrawDepositSender(_index, msg.sender);
    }

    function withdrawDepositSenderGasless(GaslessReclaim calldata reclaim, address signer, bytes calldata signature)
        external
        nonReentrant
        returns (bool)
    {
        verifyGaslessReclaim(reclaim, signer, signature);
        return _withdrawDepositSender(reclaim.depositIndex, signer);
    }

    //// Some utility functions ////

    /**
     * @notice Gets the signer of a messageHash. Used for signature verification.
     * @dev Uses ECDSA.recover. On Frontend, use secp256k1 to sign the messageHash
     * @dev also remember to prepend the messageHash with "\x19Ethereum Signed Message:\n32"
     * @param messageHash bytes32 hash of the message
     * @param signature bytes signature of the message
     * @return address of the signer
     */
    function getSigner(bytes32 messageHash, bytes memory signature) public pure returns (address) {
        address signer = ECDSA.recover(messageHash, signature);
        return signer;
    }

    /**
     * @notice Simple way to get the total number of deposits
     * @return uint256 number of deposits
     */
    function getDepositCount() external view returns (uint256) {
        return deposits.length;
    }

    /**
     * @notice Simple way to get single deposit
     * @param _index uint256 index of the deposit
     * @return Deposit struct
     */
    function getDeposit(uint256 _index) external view returns (Deposit memory) {
        return deposits[_index];
    }

    /**
     * @notice Get all deposits in contract
     * @return Deposit[] array of deposits
     */
    function getAllDeposits() external view returns (Deposit[] memory) {
        return deposits;
    }

    /**
     * @notice Get all deposits for a given address
     * @param _address address of the deposits
     * @return Deposit[] array of deposits
     */
    function getAllDepositsForAddress(address _address) external view returns (Deposit[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < deposits.length; i++) {
            if (deposits[i].senderAddress == _address) {
                count++;
            }
        }

        Deposit[] memory _deposits = new Deposit[](count);

        count = 0;
        // Second loop to populate the array
        for (uint256 i = 0; i < deposits.length; i++) {
            if (deposits[i].senderAddress == _address) {
                _deposits[count] = deposits[i];
                count++;
            }
        }
        return _deposits;
    }

    // and that's all! Have a nutty day!
}
