import os

import dotenv
from web3 import Web3

# Load .env file (../../.env)
dotenv.load_dotenv(dotenv_path="../.env")


# 1. Import the ABI and bytecode from brownie build
from brownie import PeanutV3

abi = PeanutV3.abi
bytecode = PeanutV3.bytecode


# 2. Add the Web3 provider logic here:

web3 = Web3(Web3.HTTPProvider("https://api.hyperspace.node.glif.io/rpc/v0"))  # Insert your RPC URL here

# 3. load account
private_key = os.getenv("PRIVATE_KEY")
account_from = web3.eth.account.from_key(private_key)
print(f"Attempting to deploy from account: { account_from.address }")

# 4. Create contract instance
contract = web3.eth.contract(abi=abi, bytecode=bytecode)

# 5. Build constructor tx with priority fee
construct_txn = contract.constructor().buildTransaction(
    {
        "from": account_from.address,
        "nonce": web3.eth.get_transaction_count(account_from.address),
        "maxPriorityFeePerGas": web3.toWei(3, "gwei"),
        "maxFeePerGas": web3.toWei(100, "gwei"),
    }
)

# 6. Sign tx with PK
tx_create = web3.eth.account.sign_transaction(construct_txn, account_from.key)

# 7. Send tx and wait for receipt
tx_hash = web3.eth.send_raw_transaction(tx_create.rawTransaction)
tx_receipt = web3.eth.wait_for_transaction_receipt(tx_hash)

print(f"Contract deployed at address: { tx_receipt.contractAddress }")
