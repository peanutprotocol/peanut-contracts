
    // event BatchDepositEvent(
    //     uint256[] _indexes,
    //     uint8[] _contractTypes,
    //     uint256[] _amounts,
    //     address indexed _senderAddress
    // );



    // function batchMakeDepositEther(
    //     uint256[] calldata _amounts,
    //     address[] calldata _pubKeys20
    // ) external payable returns (uint256[] memory) {
    //     require(
    //         _amounts.length == _pubKeys20.length,
    //         "PARAMETERS LENGTH MISMATCH"
    //     );

    //     uint256[] memory depositIndexes = new uint256[](_amounts.length);
    //     uint256 totalAmount = 0;

    //     for (uint256 i = 0; i < _amounts.length; i++) {
    //         totalAmount += _amounts[i];

    //         deposits.push(
    //             deposit({
    //                 tokenAddress: address(0),
    //                 contractType: 0,
    //                 amount: _amounts[i],
    //                 tokenId: 0,
    //                 pubKey20: _pubKeys20[i],
    //                 senderAddress: msg.sender,
    //                 timestamp: block.timestamp
    //             })
    //         );

    //         depositIndexes[i] = deposits.length - 1;

    //         emit DepositEvent(depositIndexes[i], 0, _amounts[i], msg.sender);
    //     }

    //     require(msg.value == totalAmount, "INVALID TOTAL ETHER SENT");

    //     return depositIndexes;
    // }

    // /**
    //  * @notice Batch ERC20 token deposit
    //  * @param _tokenAddress address of the token being sent
    //  * @param _amounts uint256 array of the amounts of tokens being sent
    //  * @param _pubKeys20 array of the last 20 bytes of the public keys of the deposit signers
    //  * @return uint256[] array of indices of the deposits
    //  */
    // function batchMakeDepositERC20(
    //     address _tokenAddress,
    //     uint256[] calldata _amounts,
    //     address[] calldata _pubKeys20
    // ) external nonReentrant returns (uint256[] memory) {
    //     require(
    //         _amounts.length == _pubKeys20.length,
    //         "PARAMETERS LENGTH MISMATCH"
    //     );

    //     uint256[] memory depositIndexes = new uint256[](_amounts.length);

    //     for (uint256 i = 0; i < _amounts.length; i++) {
    //         depositIndexes[i] = makeDeposit(
    //             _tokenAddress,
    //             1,
    //             _amounts[i],
    //             0,
    //             _pubKeys20[i]
    //         );
    //     }

    //     return depositIndexes;
    // }
