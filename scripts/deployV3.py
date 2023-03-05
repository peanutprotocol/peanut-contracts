#!/usr/bin/python3

#############################################################################################
# Usage: (venv)$ brownie run scripts/deploy.py
#   Optional: --network ...
#
#############################################################################################

import time

from brownie import PeanutERC20, PeanutV3, accounts, config, network, web3
from brownie.network import gas_price, priority_fee
from brownie.network.gas.strategies import GasNowStrategy, LinearScalingStrategy
from scripts.helpful_scripts import (
    LOCAL_BLOCKCHAIN_ENVIRONMENTS,
    estimate_cost,
    get_price,
    get_publish_source,
    get_usd_value_of_token,
)

print(f"network.show_active(): {network.show_active()}")


# # check if web3 is connected to a network
# print(f"web3.isConnected(): {web3.isConnected()}")
# if not web3.isConnected():
#     from web3 import HTTPProvider, Web3

#     rpc = "https://api.hyperspace.node.glif.io/rpc/v0"
#     web3 = Web3(HTTPProvider(rpc))
#     print(f"web3.isConnected(): {web3.isConnected()}")

# priority_fee("2 gwei")

# print compiler version
# print(f"web3.eth.getCompilers(): {web3.eth.getCompilers()}")
# raise SystemExit


def main():
    dev = accounts.add(config["wallets"]["from_key"])
    print(f"Deploying contracts to {network.show_active()}")
    print(f"Deployer account: {dev}")

    # if on local network, set gas price to 0
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        # priority_fee(0)
        # gas_price(0)
        pass

    elif "fil-hyperspace" in network.show_active():
        print("Deploying to fil-hyperspace")
        # example:
        # txn = contract.functions.makeDeposit(pwd_hash).buildTransaction(
        #     {
        #         "value": web3.toWei(amount, "ether"),
        #         "nonce": web3.eth.getTransactionCount(web3.eth.defaultAccount),
        #         "maxPriorityFeePerGas": web3.toWei(3, "gwei"),  # tip that goes to miner
        #         "maxFeePerGas": web3.toWei(100, "gwei"),  # max TOTAL fee that can be paid (per gas)
        #     }

        # deploy contract PeanutV3 from dev account using EIP-1559
        time.sleep(2)
        contract = PeanutV3.deploy(
            {
                "from": dev,
                "nonce": web3.eth.getTransactionCount(dev.address),
                "allow_revert": True,
            },
            publish_source=get_publish_source(),
        )
        # contract = PeanutV3.deploy(
        #     {"from": dev,
        #      "nonce": web3.eth.getTransactionCount(dev.address),
        #      "maxPriorityFeePerGas": web3.toWei(3, "gwei"),  # tip that goes to miner
        #      "maxFeePerGas": web3.toWei(100, "gwei"),  # max TOTAL fee that can be paid (per gas)
        #      "allow_revert": True
        #     },
        #     publish_source=get_publish_source(),
        # )

        return contract
    else:
        # set gas price 50% lower than current network gas price
        current_network_gas_price = web3.eth.generateGasPrice()
        min_gas_price = current_network_gas_price * 0.5
        max_gas_price = current_network_gas_price * 1.5
        print(
            f"Current network gas price: {current_network_gas_price / 1e9} gwei",
            f"Min gas price: {min_gas_price / 1e9} gwei",
            f"Max gas price: {max_gas_price / 1e9} gwei",
        )
        # if network polygon, set min gas price to 30 gwei (its hardcoded to prevent spam)
        if network.show_active() == "polygon-main":
            min_gas_price = "30 gwei"

        # set gas price strategy
        gas_strategy = LinearScalingStrategy(min_gas_price, max_gas_price, 1.05)
        gas_price(gas_strategy)

    contract = PeanutV3.deploy(
        {"from": dev, "nonce": web3.eth.getTransactionCount(dev.address)},
        publish_source=get_publish_source(),
    )

    # get verification info and save to json file
    with open("contract_verification_info.json", "w") as f:
        f.write(str(PeanutV3.get_verification_info()))

    # get flattened contract and save to file
    container = PeanutV3
    output = "\n\n".join(
        [x["content"] for x in container.get_verification_info()["standard_json_input"]["sources"].values()]
    )
    # remember: this is a bit of a hack, so remove all pragmas after first one, as well as the SPDX-License-Identifier
    # also order import correctly
    with open("flattened_contract.txt", "w") as f:
        f.write(output)

    # Brownies console.log equivalent
    # have to add emit events in contract...
    print()
    events = contract.tx.events  # dictionary
    if "Log" in events:
        for e in events["Log"]:
            print(e["message"])
    print()

    # get gas cost of TX
    gas_used = contract.tx.gas_used
    print(f"Gas used: {gas_used}")
    current_network = network.show_active()
    print(f"Current network: {current_network}")
    cost = estimate_cost(gas_used, current_network)
    print(f"Cost: ${cost}")

    return contract
