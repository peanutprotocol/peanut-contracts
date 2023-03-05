import brownie
import pytest
import sha3
from brownie import AuthoredEscrow, accounts, chain, network
from scripts.helpful_scripts import encode_string, get_account, hash_password

for account in accounts:
    print(f"account balance: {account.balance() / 10**18}, address: {account}")


@pytest.fixture
def owner_account():
    return accounts[0]


@pytest.fixture
def user1_account():
    return accounts[1]


@pytest.fixture
def user2_account():
    return accounts[2]


@pytest.fixture
def empty_contract(owner_account):
    current_network = network.show_active()
    print(f"current network: {current_network}")
    return AuthoredEscrow.deploy({"from": owner_account})


# contract with one deposit
@pytest.fixture
def contract_1(empty_contract, user1_account):
    contract = empty_contract
    # make one deposit
    pwd = "password"
    hashed_pwd = sha3.keccak_256(pwd.encode()).hexdigest()
    value = brownie.web3.toWei(0.123, "ether")
    tx = contract.makeDeposit(hashed_pwd, {"from": user1_account, "value": value})
    tx.wait(1)
    return contract


# contract with 10 deposits
@pytest.fixture
def contract_10(empty_contract, user1_account):
    contract = empty_contract
    # make a few deposits
    pwd = "password"
    hashed_pwd = sha3.keccak_256(pwd.encode()).hexdigest()
    value = brownie.web3.toWei(0.123, "ether")
    numDeposits = 10

    # TX
    for i in range(numDeposits):
        tx = contract.makeDeposit(hashed_pwd, {"from": user1_account, "value": value})
        # get return value
        tx.wait(1)
    return contract


def test_getDepositCount(contract_1):
    contract = contract_1
    depositCount = contract.getDepositCount()
    assert depositCount == 1


def test_getDepositCount(contract_10):
    contract = contract_10
    depositCount = contract.getDepositCount()
    assert depositCount == 10


# this is a shit spaghetti code test, pls fix
def test_depositEther(
    empty_contract,
):
    contract = empty_contract
    if network.show_active() not in ["development"] or "fork" in network.show_active():
        pytest.skip("Only for local testing")

    ## Inputs
    pwd = "password"
    pwd_hash = hash_password(pwd)
    value = brownie.web3.toWei(0.1, "ether")

    # TX
    tx = contract.makeDeposit(pwd_hash, {"from": accounts[1], "value": value})
    tx.wait(1)
    depositIdx = tx.return_value

    # Assertions
    # Check that the deposit was made
    deposit = contract.deposits(depositIdx)
    assert depositIdx == 0
    assert deposit[0] == accounts[1]
    assert deposit[1] == value
    assert deposit[2] == pwd_hash

    print(deposit[2].hex(), type(deposit[2]))
    print(deposit[2], type(deposit[2]))
    print(pwd_hash, type(pwd_hash))
    assert deposit[2] == pwd_hash

    # check that the contract balance is correct
    assert contract.balance() == value
    contract_balance1 = contract.balance()

    # check the number of deposits is correct
    assert contract.getDepositCount() == 1

    # 2. Make another deposit
    pwd = "password2"
    pwd_hash = hash_password(pwd)
    value = brownie.web3.toWei(0.2, "ether")
    value = brownie.web3.toWei(0.2, "ether")

    # TX
    tx = contract.makeDeposit(pwd_hash, {"from": accounts[1], "value": value})
    tx.wait(1)

    # Assertions
    depositIdx = tx.return_value
    assert depositIdx == 1
    print(f"depositIdx: {depositIdx}")

    # Check that the deposit was made
    deposit = contract.deposits(depositIdx)
    print(f"deposit: {deposit}")
    assert deposit[0] == accounts[1]
    assert deposit[1] == value

    print(deposit[2], type(deposit[2]))
    print(pwd_hash, type(pwd_hash))
    assert deposit[2] == pwd_hash

    # check that the contract balance is correct
    assert contract.balance() == contract_balance1 + value
    contract_balance2 = contract.balance()

    # 3. Test a withdrawal
    # function withdrawOwner(
    #     uint256 _index,
    #     address _recipient,
    #     bytes32 _pwd
    # ) external onlyOwner {
    # TX
    withdraw_account = accounts[2]
    w_balance_1 = withdraw_account.balance()
    pwd = "password2"
    pwd_encoded = encode_string(pwd)
    tx = contract.withdrawOwner(1, withdraw_account, pwd_encoded, {"from": accounts[0]})
    print(f"tx.events: {tx.events}")
    tx.wait(1)

    # Assertions
    # check that the contract balance is correct
    assert contract.balance() == contract_balance2 - value

    # check that the withdraw account balance is correct
    assert withdraw_account.balance() == w_balance_1 + value

    # check that the deposit was removed
    deposit = contract.deposits(1)
    print(f"deposit: {deposit}")
    assert deposit[0] == "0x0000000000000000000000000000000000000000"
    assert deposit[1] == 0
    assert deposit[2] == brownie.web3.toHex(brownie.web3.toBytes(0))
