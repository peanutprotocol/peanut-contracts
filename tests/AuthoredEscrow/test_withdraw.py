# import pytest
# import brownie
# from brownie import network, convert, chain, accounts, AuthoredEscrow
# from scripts.helpful_scripts import get_account
# import sha3

# for account in accounts:
#     print(f"account balance: {account.balance() / 10**18}, address: {account}")

# @pytest.fixture
# def contract():
#     contract = AuthoredEscrow.deploy({"from": accounts[0]})
#     # make a few deposits
#     pwd = "password"
#     # keccak256 hash of password
#     hashed_pwd = sha3.keccak_256(pwd.encode()).hexdigest()
#     # convert to bytes32
#     hashedPassword = convert.to_bytes(hashed_pwd)
#     depositAmount = brownie.web3.toWei(0.1, "ether")
#     unlockDepositAmount = brownie.web3.toWei(0.01, "ether")
#     numDeposits = 10

#     # TX
#     for i in range(numDeposits):
#         tx = contract.depositEther(hashedPassword, unlockDepositAmount, {"from": accounts[0], "value": depositAmount})
#         # get return value
#         tx.wait(1)
#     return contract


# def test_withdrawEtherSender(contract):
#     # test that the sender can withdraw their deposit

#     account_balance_before = accounts[0].balance()
#     contract_balance_before = contract.balance()
#     depositIdx = 0
#     value_of_deposit = contract.deposits(depositIdx)[1]

#     # TX
#     tx = contract.withdrawEtherSender(depositIdx, {"from": accounts[0]})
#     tx.wait(1)

#     # Assertions
#     account_balance_after = accounts[0].balance()
#     contract_balance_after = contract.balance()
#     assert account_balance_after == account_balance_before + value_of_deposit
#     assert contract_balance_after == contract_balance_before - value_of_deposit

#     # check that the deposit was deleted
#     deposit = contract.deposits(depositIdx)
#     print(f"deposit: {deposit}")


# def test_withdrawEtherPassword(contract):
#     # create a test deposit and test that withdrawing it with the correct password works

#     # 1. Make a deposit
#     pwd = "if you read this code send me a 'h3y' on t.me/hugomont"
#     # keccak256 hash of password
#     hashed_pwd = sha3.keccak_256(pwd.encode()).hexdigest()
#     # convert to bytes32
#     hashed_pwd_bytes = convert.to_bytes(hashed_pwd)
#     depositAmount = brownie.web3.toWei(0.1, "ether")
#     unlockDepositAmount = brownie.web3.toWei(0.01, "ether")


#     # TX
#     print(f'account balance: {brownie.web3.fromWei(accounts[0].balance(), "milliether")}, contract balance: {brownie.web3.fromWei(contract.balance(), "milliether")}')
#     tx = contract.depositEther(hashed_pwd_bytes, unlockDepositAmount, {"from": accounts[0], "value": depositAmount})
#     # get return value
#     tx.wait(1)
#     depositIdx = tx.return_value
#     print(f"deposited {depositAmount} at depositIdx {depositIdx}")

#     # 2. Withdraw the deposit with the correct password
#     account_balance_before = accounts[0].balance()
#     contract_balance_before = contract.balance()
#     value_of_deposit = contract.deposits(depositIdx)[1]
#     print(f'account balance: {brownie.web3.fromWei(accounts[0].balance(), "milliether")}, contract balance: {brownie.web3.fromWei(contract.balance(), "milliether")}')


#     # this transaction should fail:
#     with brownie.reverts():
#         tx = contract.withdrawEtherPassword(depositIdx, "incorrect password", {"from": accounts[0]})
#         tx.wait(1)


#     # now lets do it properly by first locking the deposit and THEN withdrawing it
#     # get the deposit
#     deposit = contract.deposits(depositIdx)
#     # lock TX
#     tx = contract.openEtherDepositWindow(depositIdx, {"from": accounts[0], "value": unlockDepositAmount})
#     tx.wait(1)

#     print(f'account balance: {brownie.web3.fromWei(accounts[0].balance(), "milliether")}, contract balance: {brownie.web3.fromWei(contract.balance(), "milliether")}')


#     # get the deposit and compare passwords
#     deposit = contract.deposits(depositIdx)
#     print(f"DEPOSIT: {deposit}")
#     assert deposit[4] == brownie.web3.toHex(hashed_pwd_bytes)

#     # withdraw TX with plain password
#     # this transaction should fail:
#     with brownie.reverts():
#         tx = contract.withdrawEtherPassword(depositIdx, "incorrect password", {"from": accounts[0]})
#         tx.wait(1)
#     print(f'account balance: {brownie.web3.fromWei(accounts[0].balance(), "milliether")}, contract balance: {brownie.web3.fromWei(contract.balance(), "milliether")}')


#     # this transaction should work:
#     tx = contract.withdrawEtherPassword(depositIdx, pwd, {"from": accounts[0]})
#     tx.wait(1)
#     print(f'account balance: {brownie.web3.fromWei(accounts[0].balance(), "milliether")}, contract balance: {brownie.web3.fromWei(contract.balance(), "milliether")}')


#     # Assertions
#     account_balance_after = accounts[0].balance()
#     contract_balance_after = contract.balance()
#     assert account_balance_after == account_balance_before + value_of_deposit
#     assert contract_balance_after == contract_balance_before - value_of_deposit


#     # check that the deposit was deleted
#     deposit = contract.deposits(depositIdx)
#     # assert 0 address
#     assert deposit[0] == "0x0000000000000000000000000000000000000000"

#     # try claiming the deposit again
#     with brownie.reverts():
#         tx = contract.withdrawEtherPassword(depositIdx, pwd, {"from": accounts[0]})
#         tx.wait(1)

pass
