#!/usr/bin/python3

#############################################################################################
# Usage: (venv)$ brownie run scripts/deploy.py
#   Optional: --network ...
#
#############################################################################################

from brownie import PeanutV2, accounts, config, network
from scripts.helpful_scripts import (
    estimate_cost,
    get_price,
    get_publish_source,
    get_usd_value_of_token,
)


def main():
    dev = accounts.add(config["wallets"]["from_key"])
    print(f"Deploying contracts to {network.show_active()}")
    print(f"Deployer account: {dev}")

    contract = PeanutV2.deploy(
        {"from": dev},
        publish_source=get_publish_source(),
    )

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

    # print owner of contract
    print(f"Owner address: {contract.owner()}")

    return contract
