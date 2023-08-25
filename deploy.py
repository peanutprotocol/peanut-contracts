##############
# WIP script
# TODO:
# - manage 'legacy' flag for chains (in foundry.toml as a comment? again?)
# - NEW LINE: goerli = "https://goerli.infura.io/v3/${INFURA_API_KEY}" # 5 # legacy <-- this one has legacy flag, so the command should include it
# - manage shortened version mapping to full version (ie v3, v4, v4b)
##############
import os
import json
import subprocess
from typing import List, Dict, Tuple
import argparse
import toml
import dotenv

dotenv.load_dotenv()

# Load the foundry.toml file
config = toml.load("foundry.toml")

# Definitions
CONTRACTS_MAPPING = {"PeanutV3": "v3", "PeanutV4": "v4", "PeanutBatcherV4": "v4b"}
CONTRACTS = list(CONTRACTS_MAPPING.keys())
CONTRACTS_JSON_PATH = "contracts.json"


def has_etherscan_key(chain: str) -> bool:
    return chain in config["etherscan"]


def run_command(command: str) -> str:
    env = os.environ.copy()
    process = subprocess.run(
        command,
        shell=True,
        check=True,
        stdout=subprocess.PIPE,
        universal_newlines=True,
        env=env,
    )
    return process.stdout


def extract_contract_address(contract_name: str, chain_id: str) -> str:
    path = f"out/broadcast/{contract_name}.sol/{chain_id}/run-latest.json"

    with open(path, "r") as file:
        data = json.load(file)

    if data.get("transactions") and len(data["transactions"]) > 0:
        return data["transactions"][0].get("contractAddress")
    else:
        print(
            f"Error: Unable to find contract address for {contract_name} in the JSON file."
        )
        return None


def get_chain_info(chain: str) -> Tuple[bool, str]:
    """Determine if a chain is legacy and also extract its chain ID."""
    chain_info = config["rpc_endpoints"][chain].split("#")
    if len(chain_info) > 2 and chain_info[2].strip() == "legacy":
        return True, chain_info[1].strip()
    return False, chain_info[-1].strip()


def deploy_to_chain(chain: str, contracts: List[str]):
    if chain not in config["rpc_endpoints"]:
        print(f"Error: Unknown chain {chain}")
        return

    if not has_etherscan_key(chain):
        print(
            f"Error: foundry.toml does not include an etherscan verification key for {chain}"
        )
        return

    legacy, chain_id = get_chain_info(chain)

    for contract in contracts:
        command = f"forge script script/{contract}.s.sol:DeployScript --rpc-url {config['rpc_endpoints'][chain]} --broadcast"
        if legacy:
            command += " --legacy"
        else:
            command += " --verify -vvvv"

        print(f"Deploying {contract} to {chain}")
        output = run_command(command)
        print(f"Deployment output:\n{output}")

        contract_address = extract_contract_address(contract, chain_id)

        with open(CONTRACTS_JSON_PATH, "r") as file:
            contracts_json = json.load(file)

        short_contract_name = CONTRACTS_MAPPING.get(contract)
        contracts_json.setdefault(chain, {})[short_contract_name] = contract_address

        with open(CONTRACTS_JSON_PATH, "w") as file:
            json.dump(contracts_json, file, indent=4)


def deploy_to_all_chains(contracts: List[str]):
    for chain in config["rpc_endpoints"].keys():
        user_input = input(f"Deploy to {chain}? (y/n) ")
        if user_input == "y":
            deploy_to_chain(chain, contracts)


def deploy_to_specific_chain(chain: str, contracts: List[str]):
    if chain not in config["rpc_endpoints"]:
        print(f"Error: Unknown chain {chain}")
        return

    deploy_to_chain(chain, contracts)


def main():
    epilog_text = """
Examples of using this script:

Help:
  python3 deploy.py -h

Deploy PeanutV4 only on goerli:
  python deploy.py -c PeanutV3 -ch goerli

Deploying Multiple Contracts to a Specific Chain:
  python deploy.py -c PeanutV3 PeanutV4 -ch goerli

Deploying a specific contract to all chains:
  python script_name.py -c PeanutV4

Notice: you have to update CONTRACTS_MAPPING and foundry.toml for this script to work.
example foundry.toml [rpc_endpoints] entry:
goerli = "https://goerli.infura.io/v3/${INFURA_API_KEY}" # 5 # legacy
    """

    parser = argparse.ArgumentParser(
        description="Deploy contracts to blockchain chains.",
        epilog=epilog_text,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "-c",
        "--contracts",
        nargs="+",
        choices=CONTRACTS,
        help="Specify which contracts to deploy.",
    )
    parser.add_argument(
        "-ch",
        "--chain",
        type=str,
        help="Specify a specific chain to deploy to. If not provided, will ask for all chains.",
    )
    args = parser.parse_args()

    if args.chain:
        deploy_to_specific_chain(args.chain, args.contracts)
    else:
        deploy_to_all_chains(args.contracts)


if __name__ == "__main__":
    main()
