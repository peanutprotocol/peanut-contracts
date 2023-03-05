# Run with:  brownie test tests/PeanutV3/test_base.py  (from root brownie directory)

import brownie
import pytest
import sha3
from brownie import (
    PeanutERC20,
    PeanutERC721,
    PeanutERC1155,
    PeanutV3,
    accounts,
    chain,
    network,
)
from scripts.helpful_scripts import encode_string, get_account  # , sign_message

for account in accounts:
    print(f"account balance: {account.balance() / 10**18}, address: {account}")


@pytest.fixture
def peanut_contract():
    # return accounts[0].deploy(PeanutV3)
    return PeanutV3.deploy({"from": accounts[0]})


@pytest.fixture
def peanut_erc20():
    return PeanutERC20.deploy({"from": accounts[0]})


@pytest.fixture
def peanut_erc721():
    return PeanutERC721.deploy({"from": accounts[0]})


@pytest.fixture
def peanut_erc1155():
    return PeanutERC1155.deploy({"from": accounts[0]})


# Test supportsInterface
def test_supportsInterface(peanut_contract):
    contract = peanut_contract
    # test supportsInterface
    interfaceId = contract.supportsInterface("0x01ffc9a7")
    assert interfaceId == True

    # test IERC721Receiver
    interfaceId = contract.supportsInterface("0x150b7a02")
    assert interfaceId == True

    # test IERC1155Receiver
    interfaceId = contract.supportsInterface("0x4e2312e0")
    assert interfaceId == True


# Test makeDeposit
# Reference parameters:
# /**
#      * @notice Function to make a deposit
#      * @dev For token deposits, allowance must be set before calling this function
#      * @param _tokenAddress address of the token being sent. 0x0 for eth
#      * @param _contractType uint8 for the type of contract being sent. 0 for eth, 1 for erc20, 2 for erc721, 3 for erc1155
#      * @param _amount uint256 of the amount of tokens being sent (if erc20)
#      * @param _tokenId uint256 of the id of the token being sent if erc721 or erc1155
#      * @param _pubKey20 last 20 bytes of the public key of the deposit signer
#      * @return uint256 index of the deposit
# */
def test_makeDeposit_base(peanut_contract):
    contract = peanut_contract

    # 1. Make a deposit
    tokenAddress = "0x0000000000000000000000000000000000000000"
    contractType = 0
    amount = 0
    tokenId = 0
    pubKey20 = "0x0000000000000000000000000000000000000000"
    tx_value = brownie.web3.toWei(0.33, "ether")

    # 2. TX
    tx = peanut_contract.makeDeposit(
        tokenAddress,
        contractType,
        amount,
        tokenId,
        pubKey20,
        {"from": accounts[0], "value": tx_value},
    )
    print(tx.events)

    # 3. Check deposit & assertions
    # Reference:
    # struct deposit {
    #     address pubKey20; // last 20 bytes of the hash of the public key for the deposit
    #     uint256 amount; // amount of the asset being sent
    #     address tokenAddress; // address of the asset being sent. 0x0 for eth
    #     uint8 contractType; // 0 for eth, 1 for erc20, 2 for erc721, 3 for erc1155
    #     uint256 tokenId; // id of the token being sent (if erc721 or erc1155)
    # }
    deposit = peanut_contract.deposits(0)
    assert deposit[0] == pubKey20
    assert deposit[1] == tx_value
    assert deposit[2] == tokenAddress
    assert deposit[3] == contractType
    assert deposit[4] == tokenId

    # 4. Check balance
    contract_balance = peanut_contract.balance()
    assert contract_balance == tx_value


def test_makeDeposit_erc20(peanut_contract, peanut_erc20):

    # 1. Make a deposit
    tokenAddress = peanut_erc20.address
    contractType = 1
    amount = 10
    tokenId = 0
    pubKey20 = "0x0000000000000000000000000000000000000000"
    tx_value = brownie.web3.toWei(0, "ether")

    # 2. TX
    # this transaction should fail because the contract does not have enough allowance
    with brownie.reverts():
        tx = peanut_contract.makeDeposit(
            tokenAddress,
            contractType,
            amount,
            tokenId,
            pubKey20,
            {"from": accounts[0], "value": tx_value},
        )

    # 3. Approve allowance before making deposit
    peanut_erc20.approve(peanut_contract.address, amount, {"from": accounts[0]})
    tx = peanut_contract.makeDeposit(
        tokenAddress,
        contractType,
        amount,
        tokenId,
        pubKey20,
        {"from": accounts[0], "value": tx_value},
    )
    print(tx.events)

    # 4. Check deposit & assertions
    deposit = peanut_contract.deposits(0)
    assert deposit[0] == pubKey20
    assert deposit[1] == amount
    assert deposit[2] == tokenAddress
    assert deposit[3] == contractType
    assert deposit[4] == tokenId

    # 5. Check balance
    contract_balance = peanut_erc20.balanceOf(peanut_contract.address)
    assert contract_balance == amount


def test_makeDeposit_erc721(peanut_contract, peanut_erc721):
    # 0. Mint token and get token id from return value
    tx = peanut_erc721.mint(accounts[0], "https://peanut.com", {"from": accounts[0]})
    tokenId = tx.events["Transfer"]["tokenId"]
    print("tokenId: ", tokenId)

    # 1. Make a deposit
    tokenAddress = peanut_erc721.address
    contractType = 2
    amount = 0
    tokenId = tokenId
    pubKey20 = "0x0000000000000000000000000000000000000000"
    tx_value = brownie.web3.toWei(0, "ether")

    # 2. TX
    # this transaction should fail because the contract does not have enough allowance
    with brownie.reverts():
        tx = peanut_contract.makeDeposit(
            tokenAddress,
            contractType,
            amount,
            tokenId,
            pubKey20,
            {"from": accounts[0], "value": tx_value},
        )

    # 3. Approve allowance before making deposit
    peanut_erc721.approve(peanut_contract.address, tokenId, {"from": accounts[0]})
    tx = peanut_contract.makeDeposit(
        tokenAddress,
        contractType,
        amount,
        tokenId,
        pubKey20,
        {"from": accounts[0], "value": tx_value},
    )
    print(tx.events)

    # 4. Check deposit & assertions
    deposit = peanut_contract.deposits(0)
    assert deposit[0] == pubKey20
    assert deposit[1] == amount
    assert deposit[2] == tokenAddress
    assert deposit[3] == contractType
    assert deposit[4] == tokenId

    # 5. Check balance
    contract_balance = peanut_erc721.balanceOf(peanut_contract.address)
    assert contract_balance == 1


def test_makeDeposit_erc1155(peanut_contract, peanut_erc1155):
    # 0. Mint some tokens
    token_id = 0  # gold
    tx = peanut_erc1155.mint(accounts[0], token_id, 100, "", {"from": accounts[0]})
    tokenId = tx.events["TransferSingle"]["id"]
    print("tokenId: ", tokenId)

    # 1. Make a deposit
    tokenAddress = peanut_erc1155.address
    contractType = 3
    amount = 100
    tokenId = tokenId
    pubKey20 = "0x0000000000000000000000000000000000000000"
    tx_value = brownie.web3.toWei(0, "ether")

    # 2. TX
    # this transaction should fail because the contract does not have enough allowance
    with brownie.reverts():
        tx = peanut_contract.makeDeposit(
            tokenAddress,
            contractType,
            amount,
            tokenId,
            pubKey20,
            {"from": accounts[0], "value": tx_value},
        )

    # 3. Approve allowance before making deposit
    peanut_erc1155.setApprovalForAll(peanut_contract.address, True, {"from": accounts[0]})
    tx = peanut_contract.makeDeposit(
        tokenAddress,
        contractType,
        amount,
        tokenId,
        pubKey20,
        {"from": accounts[0], "value": tx_value},
    )
    print(tx.events)

    # 4. Check deposit & assertions
    deposit = peanut_contract.deposits(0)
    assert deposit[0] == pubKey20
    assert deposit[1] == amount
    assert deposit[2] == tokenAddress
    assert deposit[3] == contractType
    assert deposit[4] == tokenId

    # 5. Check balance
    contract_balance = peanut_erc1155.balanceOf(peanut_contract.address, tokenId)
    assert contract_balance == amount


### WITHDRAWAL TESTS ###
@pytest.fixture
def peanut_contract_with_erc20deposit(peanut_contract, peanut_erc20):
    # 0. generate public/private key pair
    # temp
    privkey = "0xb94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
    pubAddress = "0x09332B1E45e6172fB26E46B3DB4411201547560a"

    # 1. Make a deposit
    tokenAddress = peanut_erc20.address
    contractType = 1
    amount = 10
    tokenId = 0
    pubKey20 = pubAddress
    tx_value = brownie.web3.toWei(0, "ether")

    # 2. Approve allowance before making deposit
    peanut_erc20.approve(peanut_contract.address, amount, {"from": accounts[0]})
    tx = peanut_contract.makeDeposit(
        tokenAddress,
        contractType,
        amount,
        tokenId,
        pubKey20,
        {"from": accounts[0], "value": tx_value},
    )
    print(tx.events)

    return peanut_contract


def test_withdrawal_erc20(peanut_contract_with_erc20deposit, peanut_erc20):
    # 0. generate public/private key pair
    # temp
    privkey = "0xb94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
    pubAddress = "0x09332B1E45e6172fB26E46B3DB4411201547560a"

    # 1. Withdraw
    # function withdrawDeposit(
    #     uint256 _index,
    #     address _recipientAddress,
    #     bytes32 _recipientAddressHash,
    #     bytes memory _signature
    # )
    tokenId = 0
    pubKey20 = pubAddress
    recipientAddress = "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
    recipientAddressHash = (
        "0xcd9ed0433174d173b609ed57aa4b81fb9b9dc8b800fb0b7743d1d703bacf1b24"  # hash(prefx + hash(recipientAddress)
    )
    tx_value = brownie.web3.toWei(0, "ether")

    balance_before = peanut_erc20.balanceOf(recipientAddress)
    signature = "0xcffbbbc4a538238a7945baffad39d6950fd424a52144bb9beb680ebbc85d7f026274d8449192b49a635d63f2fa886fa0c61f9b9aa920cbd228afb8a34c7cb9711b"

    # 2. TX
    # withdraw the ether
    tx = peanut_contract_with_erc20deposit.withdrawDeposit(
        tokenId,
        recipientAddress,
        recipientAddressHash,
        signature,
        {"from": accounts[0], "value": tx_value},
    )

    # 3. Check balance
    balance_after = peanut_erc20.balanceOf(recipientAddress)
    assert balance_after == balance_before + 10

    # 4. Check deposit is withdrawn (all fields are 0)
    deposit = peanut_contract_with_erc20deposit.deposits(0)
    assert deposit[0] == "0x0000000000000000000000000000000000000000"
    assert deposit[1] == 0
    assert deposit[2] == "0x0000000000000000000000000000000000000000"
    assert deposit[3] == 0
    assert deposit[4] == 0

    # 5. Check balance
    contract_balance = peanut_erc20.balanceOf(peanut_contract_with_erc20deposit.address)
    assert contract_balance == 0


### WITHDRAWAL TESTS ###
@pytest.fixture
def peanut_contract_with_erc721deposit(peanut_contract, peanut_erc721):
    # 0. Mint some tokens
    tx = peanut_erc721.mint(accounts[0], "jpeg.url", {"from": accounts[0]})
    tokenId = tx.events["Transfer"]["tokenId"]
    print("tokenId: ", tokenId)

    # 1. Make a deposit
    # temp
    privkey = "0xb94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
    pubAddress = "0x09332B1E45e6172fB26E46B3DB4411201547560a"

    tokenAddress = peanut_erc721.address
    contractType = 2
    amount = 1
    tokenId = tokenId
    pubKey20 = pubAddress

    # 2. Approve allowance before making deposit
    peanut_erc721.approve(peanut_contract.address, tokenId, {"from": accounts[0]})
    tx = peanut_contract.makeDeposit(
        tokenAddress,
        contractType,
        amount,
        tokenId,
        pubKey20,
        {"from": accounts[0], "value": 0},
    )
    print(tx.events)

    return peanut_contract


def test_withdrawal_erc721(peanut_contract_with_erc721deposit, peanut_erc721):
    # 0. generate public/private key pair
    # temp
    privkey = "0xb94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
    pubAddress = "0x09332B1E45e6172fB26E46B3DB4411201547560a"

    # 1. Withdraw
    # function withdrawDeposit(
    #     uint256 _index,
    #     address _recipientAddress,
    #     bytes32 _recipientAddressHash,
    #     bytes memory _signature
    # )
    tokenId = 0
    pubKey20 = pubAddress
    recipientAddress = "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
    recipientAddressHash = (
        "0xcd9ed0433174d173b609ed57aa4b81fb9b9dc8b800fb0b7743d1d703bacf1b24"  # hash(prefx + hash(recipientAddress)
    )
    tx_value = brownie.web3.toWei(0, "ether")

    balance_before = peanut_erc721.balanceOf(recipientAddress)
    signature = "0xcffbbbc4a538238a7945baffad39d6950fd424a52144bb9beb680ebbc85d7f026274d8449192b49a635d63f2fa886fa0c61f9b9aa920cbd228afb8a34c7cb9711b"

    # 2. TX
    # withdraw the deposit
    tx = peanut_contract_with_erc721deposit.withdrawDeposit(
        tokenId,
        recipientAddress,
        recipientAddressHash,
        signature,
        {"from": accounts[0], "value": tx_value},
    )

    # 3. Check balance
    balance_after = peanut_erc721.balanceOf(recipientAddress)
    assert balance_after == balance_before + 1

    # 4. Check deposit is withdrawn (all fields are 0)
    deposit = peanut_contract_with_erc721deposit.deposits(0)
    assert deposit[0] == "0x0000000000000000000000000000000000000000"
    assert deposit[1] == 0
    assert deposit[2] == "0x0000000000000000000000000000000000000000"
    assert deposit[3] == 0
    assert deposit[4] == 0

    # 5. Check balance
    contract_balance = peanut_erc721.balanceOf(peanut_contract_with_erc721deposit.address)
    assert contract_balance == 0
