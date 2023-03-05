import os
import time

import requests
import sha3
from brownie import Contract, accounts, chain, config, network, web3

# Set a default gas price
from brownie.network import priority_fee

NON_FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["hardhat", "development", "ganache"]
LOCAL_BLOCKCHAIN_ENVIRONMENTS = NON_FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS + [
    "mainnet-fork",
    "binance-fork",
    "matic-fork",
]


def get_account(index=None, id=None):
    if index:
        return accounts[index]
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        return accounts[0]
    if id:
        return accounts.load(id)
    if network.show_active() in config["networks"]:
        return accounts.add(config["wallets"]["from_key"])
    return None


# don't attempt to publish source on local networks
def get_publish_source():
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        return False
    else:
        return True


def get_verify_status():
    verify = (
        config["networks"][network.show_active()]["verify"]
        if config["networks"][network.show_active()].get("verify")
        else False
    )
    return verify


def listen_for_event(brownie_contract, event, timeout=200, poll_interval=2):
    """Listen for an event to be fired from a contract.
    We are waiting for the event to return, so this function is blocking.

    Args:
        brownie_contract ([brownie.network.contract.ProjectContract]):
        A brownie contract of some kind.

        event ([string]): The event you'd like to listen for.

        timeout (int, optional): The max amount in seconds you'd like to
        wait for that event to fire. Defaults to 200 seconds.

        poll_interval ([int]): How often to call your node to check for events.
        Defaults to 2 seconds.
    """
    web3_contract = web3.eth.contract(address=brownie_contract.address, abi=brownie_contract.abi)
    start_time = time.time()
    current_time = time.time()
    event_filter = web3_contract.events[event].createFilter(fromBlock="latest")
    while current_time - start_time < timeout:
        for event_response in event_filter.get_new_entries():
            if event in event_response.event:
                print("Found event!")
                return event_response
        time.sleep(poll_interval)
        current_time = time.time()
    print("Timeout reached, no event found.")
    return {"event": None}


# @dev: keep up to date with crypto.py
# code duplication isn't the best, but there doesn't seem to be a better solution
def encode_string(string):
    # Equivalent (?)
    # pwd_bytes32 = pwd.encode("utf-8").ljust(32, b"\x00")
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
        return 1000.0


def get_usd_value_of_token(amount, token):
    token_dict = {
        "ethereum": "ETH",
        "polygon": "MATIC",
        "optimism": "ETH",
        "arbitrum": "ETH",
        "starknet": "ETH",
        "near": "NEAR",
        "avalanche": "AVAX",
    }
    if token in token_dict:
        token = token_dict[token]
    price = get_price(token)
    usd_value = float(price) * float(amount)
    return usd_value


def estimate_cost(gas, chain):
    # estimates the dollar cost of n gas amount
    gas_price = web3.eth.gasPrice
    SYMBOLS = {
        "ethereum": "ETH",
        "polygon": "MATIC",
        "optimism": "ETH",
        "arbitrum": "ETH",
        "starknet": "ETH",
        "near": "NEAR",
        "avalanche": "AVAX",
    }
    try:
        eth_price = get_price(SYMBOLS[chain])
    except Exception as e:
        print(f"Error getting price for {chain}: {e}")
        eth_price = 1000.0
    print(f"gas: {gas}, gas_price: {gas_price}, eth_price: {eth_price}")
    cost = (gas * gas_price) / 10**18 * float(eth_price)
    return cost
