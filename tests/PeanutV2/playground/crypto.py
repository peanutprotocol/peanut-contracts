# @dev TODO: it's not a good practice to import hardcoded stuff like config in this file. This should be _independent_,
# decoupled from stuff like config.py and contracts.json.
# TODO: decouple. Remove all CONTRACTS[] etc and make them function args


import os

import config  # config.CONTRACTS +& config.ABI
import dotenv
import requests
import sha3
from web3 import Web3
from web3.middleware import geth_poa_middleware

if not os.path.exists("../../../.env"):
    raise Exception("No .env file found. Please create one.")
dotenv.load_dotenv("../../../.env")  # load .env vars
ADMIN_ACCOUNT_KEY = os.getenv("PRIVATE_KEY")
# raise exception if no .env file
CONTRACTS = config.CONTRACTS
ABI = config.ABI
PROVIDERS = {
    "ethereum": {
        "mainnet": "https://mainnet.infura.io/v3/",
        "goerli": "https://goerli.infura.io/v3/",
    },
    "polygon": {
        "mainnet": "https://polygon-mainnet.infura.io/v3/",
        "mumbai": "https://polygon-mumbai.infura.io/v3/",
    },
    "optimism": {
        "mainnet": "https://optimism-mainnet.infura.io/v3/",
        "kovan": "https://optimism-kovan.infura.io/v3/",
    },
    "arbitrum": {
        "mainnet": "https://arbitrum-mainnet.infura.io/v3/",
        "rinkeby": "https://arbitrum-rinkeby.infura.io/v3/",
    },
    "starknet": {
        "mainnet": "https://starknet-mainnet.infura.io/v3/",
        "goerli": "https://starknet-mainnet.infura.io/v3/",
    },
    "near": {
        "mainnet": "https://near-mainnet.infura.io/v3/",
        "testnet": "https://near-testnet.infura.io/v3/",
    },
    "avalanche": {},
    "moonbeam": {
        "mainnet": "https://moonbeam-mainnet.infura.io/v3/",
    },
}
SYMBOLS = {
    "ethereum": "ETH",
    "polygon": "MATIC",
    "optimism": "ETH",
    "arbitrum": "ETH",
    "starknet": "ETH",
    "near": "NEAR",
    "avalanche": "AVAX",
}


def encode_string(string):
    return string.encode().rjust(32, b"\0")


def hash_bytes32(bytes32):
    hash = sha3.keccak_256(bytes32).hexdigest()
    hash = "0x" + hash
    return hash


def hash_password(pwd):
    pwd_bytes32 = encode_string(pwd)
    return hash_bytes32(pwd_bytes32)


# get current price of a token
def get_price(token):
    try:
        url = "https://api.binance.com/api/v3/ticker/price"
        params = {"symbol": token + "USDT"}
        response = requests.get(url, params=params)
        data = response.json()
        price = data["price"]
        return price
    except Exception as e:
        print(f"Error getting price for {token}: {e}")
        return None


def get_usd_value_of_token(amount, token):
    token_dict = {
        "ethereum": "ETH",
        "polygon": "MATIC",
        "optimism": "ETH",
        "arbitrum": "ETH",
        "starknet": "ETH",
        "near": "NEAR",
        "avalanche": "AVAX",
        "moonbeam": "GLMR",
    }
    if token in token_dict:
        token = token_dict[token]
    price = get_price(token)
    usd_value = float(price) * float(amount)
    return usd_value


def estimate_cost(gas, chain, web3):
    # estimates the dollar cost of n gas amount
    gas_price = web3.eth.gasPrice
    eth_price = get_price(SYMBOLS[chain])
    print(f"gas: {gas}, gas_price: {gas_price}, eth_price: {eth_price}")
    cost = (gas * gas_price) / 10**18 * float(eth_price)
    return cost


def get_contract(address, abi, network):
    """creates an instance of a contract on a specific network.
    network should take the form of ethereum-mainnet, polygon-mumbai, etc."""

    # connect to network & set default account
    chain, subchain = network.split("-")
    provider = Web3.HTTPProvider(f"{PROVIDERS[chain][subchain]}{os.getenv('WEB3_INFURA_PROJECT_ID')}")
    web3 = Web3(provider)

    # @dev why tf are we doing this? this has nth to do with get_contract()
    web3.eth.defaultAccount = web3.eth.account.privateKeyToAccount(ADMIN_ACCOUNT_KEY).address

    # if polygon, add poa middleware
    if "polygon" in network:
        print("adding poa middleware")
        web3.middleware_onion.inject(geth_poa_middleware, layer=0)
    # create contract instance
    contract = web3.eth.contract(address=address, abi=abi)
    return contract, web3


def resolve_ens_name(name):
    provider = Web3.HTTPProvider(f"{PROVIDERS['ethereum']['mainnet']}{os.getenv('WEB3_INFURA_PROJECT_ID')}")
    web3 = Web3(provider)
    return web3.ens.address(name)


def make_deposit(amount, password, network):
    """makes a deposit to the contract on a specific network."""

    # get contract instance
    chain, subchain = network.split("-")
    contract_address = CONTRACTS[chain][subchain]
    contract, web3 = get_contract(contract_address, ABI, network)
    ADMIN_ACCOUNT = web3.eth.account.privateKeyToAccount(ADMIN_ACCOUNT_KEY)
    print(
        f"Contract Balance: {web3.eth.getBalance(contract_address)}",
        f"Depositing {amount}\n",
    )

    # create and sign transaction (EIP-1559)
    # @dev TODO: nonce is a potential problem. What if 2 txs are sent to mempool at the same time?
    # --> 2nd tx will fail. Need to account for this.
    pwd_hash = hash_password(password)

    # @dev TODO: set a reasonable max fee per gas per network. ETH mainnet not the same as polygon.
    # txn = contract.functions.makeDeposit(pwd_hash).buildTransaction(
    #     {
    #         "value": web3.toWei(amount, "ether"),
    #         "nonce": web3.eth.getTransactionCount(web3.eth.defaultAccount),
    #         "maxPriorityFeePerGas": web3.toWei(3, "gwei"),  # tip that goes to miner
    #         "maxFeePerGas": web3.toWei(100, "gwei"),  # max TOTAL fee that can be paid (per gas)
    #     }
    # ) OPTIMISM HAS NO EIP-1559
    txn = contract.functions.makeDeposit(pwd_hash).buildTransaction(
        {
            "value": web3.toWei(amount, "ether"),
            "gas": 200000,
            "gasPrice": web3.eth.gasPrice,
            "nonce": web3.eth.getTransactionCount(web3.eth.defaultAccount),
        }
    )
    signed_txn = ADMIN_ACCOUNT.signTransaction(txn)
    # estimate gas & cost

    gas_estimate = web3.eth.estimateGas(txn)
    print(f"Gas Estimate: {gas_estimate}")
    print(f"TX cost Estimate: ${estimate_cost(gas_estimate, chain, web3)}")

    tx_hash = web3.eth.sendRawTransaction(signed_txn.rawTransaction)
    tx_receipt = web3.eth.waitForTransactionReceipt(tx_hash)
    print(f"Deposit tx hash: {web3.toHex(tx_receipt.transactionHash)}")
    print(f"Contract balance after deposit: {web3.eth.getBalance(contract_address)}")
    print(f"Actual gas used: {tx_receipt.gasUsed}")
    return tx_receipt, web3.toHex(tx_receipt.transactionHash)


def make_withdrawal(index, recipient, password, network):
    """makes a withdrawal from the contract on a specific network.
    @param index: index of the deposit to withdraw
    @param recipient: address to send the withdrawal to
    @param password: password to unlock the deposit
    @param network: network to make the withdrawal on (e.g. ethereum-mainnet)
    """

    chain, subchain = network.split("-")

    # get contract instance
    contract_address = CONTRACTS[chain][subchain]
    contract, web3 = get_contract(contract_address, ABI, network)
    ADMIN_ACCOUNT = web3.eth.account.privateKeyToAccount(ADMIN_ACCOUNT_KEY)
    print(
        f"Contract Balance: {web3.eth.getBalance(contract_address)}",
        f"Withdrawing {index} to {recipient}\n",
    )

    # 1. call contract withdrawOwner
    pwd_bytes32 = encode_string(password)
    # cast index to uint256 and recipient to address
    index = int(index)
    recipient = web3.toChecksumAddress(recipient)
    txn = contract.functions.withdrawOwner(index, recipient, pwd_bytes32).buildTransaction(
        {
            "gas": 700000,  # apparently Optimism requires much higher gas limits?? 240k or so.... (still just $0.04)
            "gasPrice": web3.eth.gasPrice,
            "nonce": web3.eth.getTransactionCount(web3.eth.defaultAccount),
        }
    )
    signed_txn = ADMIN_ACCOUNT.signTransaction(txn)
    # estimate gas & cost
    try:
        gas_estimate = web3.eth.estimateGas(txn)
    except ValueError as e:
        print(e)
        return
    print(f"Gas Estimate: {gas_estimate}")
    print(f"TX cost Estimate: ${estimate_cost(gas_estimate, chain, web3)}")

    # 2. send transaction
    tx_hash = web3.eth.sendRawTransaction(signed_txn.rawTransaction)
    tx_receipt = web3.eth.waitForTransactionReceipt(tx_hash)
    print(f"Transaction hash: {web3.toHex(tx_receipt.transactionHash)}")
    print(f"Contract balance after withdrawal: {web3.eth.getBalance(contract_address)}")
    print(f"Actual gas used: {tx_receipt.gasUsed}")
    return tx_receipt, web3.toHex(tx_receipt.transactionHash)


def get_deposits(address, network):
    """gets all deposits for a given address on a given network."""
    chain, subchain = network.split("-")
    contract_address = CONTRACTS[chain][subchain]
    contract, web3 = get_contract(contract_address, ABI, network)
    deposits = contract.functions.getDeposits(address).call()
    return deposits


## UTIL
toChecksumAddress = Web3.toChecksumAddress


def check_if_address_is_valid(address):
    return Web3().isAddress(address)
