import os
import json
import subprocess
from typing import List, Dict, Tuple
import argparse
import toml
import dotenv
import time

dotenv.load_dotenv()

# Load the foundry.toml file
config = toml.load("foundry.toml")

# Definitions
CONTRACTS_MAPPING = {"PeanutV3": "v3", "PeanutV4": "v4", "PeanutBatcherV4": "Bv4"}
CONTRACTS = list(CONTRACTS_MAPPING.keys())
CONTRACTS_JSON_PATH = "contracts.json"


def has_etherscan_key(chain: str) -> bool:
    return chain in config["etherscan"]


def run_command(command: str) -> str:
    env = os.environ.copy()

    with subprocess.Popen(
        command,
        shell=True,
        stdout=subprocess.PIPE,
        universal_newlines=True,
        env=env,
        bufsize=1,
    ) as process:
        output = []
        for line in process.stdout:
            print(line, end="")  # Print in real-time.
            output.append(line)

        process.communicate()  # Ensure process completes.
        if process.returncode != 0:
            raise subprocess.CalledProcessError(process.returncode, command)

    return "".join(output)


def extract_contract_address(contract_name: str, chain_id: str) -> str:
    path = f"broadcast/{contract_name}.s.sol/{chain_id}/run-latest.json"

    with open(path, "r") as file:
        data = json.load(file)

    if data.get("transactions") and len(data["transactions"]) > 0:
        return data["transactions"][0].get("contractAddress")
    else:
        print(
            f"Error: Unable to find contract address for {contract_name} in the JSON file."
        )
        return None


def get_chain_info(chain: str) -> Tuple[str, bool]:
    """Determine if a chain is legacy and also extract its chain ID."""
    chain_info = config["rpc_endpoints"].get(chain)
    if not chain_info:
        print(f"Error: chain {chain} is not in the configuration.")
        raise ValueError(f"Error: chain {chain} is not in the configuration.")

    chain_id = config["profile"]["chain_ids"].get(chain)
    legacy = config["profile"]["legacy"].get(chain, False)

    return chain_id, legacy


def deploy_contract(command: str) -> str:
    """Attempts to deploy a contract and retries without broadcast flag if necessary."""
    output = run_command(command)

    # Check if there's an Etherscan error
    if "Etherscan could not detect the deployment." in output:
        print("Etherscan verification failed. Retrying without --broadcast flag...")
        time.sleep(30)  # Wait for 30 seconds
        command = command.replace("--broadcast", "")
        output = run_command(command)

    return output


def deploy_to_chain(chain: str, contracts: List[str]):

    if not has_etherscan_key(chain):
        print(
            f"Error: foundry.toml does not include an etherscan verification key for {chain}"
        )
        return

    if chain not in config["rpc_endpoints"]:
        print(f"Error: foundry.toml rpc_endpoints does not include chain {chain}")
        return

    chain_id, legacy = get_chain_info(chain)

    for contract in contracts:
        with open(CONTRACTS_JSON_PATH, "r") as file:
            contracts_json = json.load(file)

        short_contract_name = CONTRACTS_MAPPING.get(contract)
        if not short_contract_name:
            print(f"Error: {contract} is not in the CONTRACTS_MAPPING.")
            return

        # Check if the contract already exists
        existing_address = contracts_json[chain_id].get(short_contract_name)
        if existing_address:
            # Show a warning
            print(
                f"Warning: Contract {short_contract_name} already exists for {chain} at address {existing_address}."
            )
            overwrite = input("Do you want to overwrite? (y/n) ")
            if overwrite.lower() != "y":
                print(f"Skipped deploying & overwriting {contract} ({short_contract_name}) for {chain}.")
                continue  # Skip the rest of the loop and move to the next contract

        command = f"forge script script/{contract}.s.sol:DeployScript --rpc-url {config['rpc_endpoints'][chain]} --broadcast --verify -vvvv"
        if legacy:
            command += " --legacy"
            print(f"Using legacy mode for {chain}")

        print(f"Deploying {contract} to {chain}")
        output = deploy_contract(command)  # use the new deploy_contract function

        contract_address = extract_contract_address(contract, chain_id)

        print(f"Deployed {contract} to {chain} at {contract_address}.")

        # Make sure chain_id exists in the json
        if chain_id not in contracts_json:
            contracts_json[chain_id] = {}

        contracts_json[chain_id][short_contract_name] = contract_address

        with open(CONTRACTS_JSON_PATH, "w") as file:
            json.dump(contracts_json, file, indent=4)
        print(f"Saved {contract} to {chain} at {contract_address} in contracts.json")


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

Deploy single contract on single chain:
  python3 deploy.py -c PeanutBatcherV4 -ch polygon-mumbai

Deploying Multiple Contracts to a Specific Chain:
  python3 deploy.py -c PeanutV3 PeanutV4 -ch goerli

Deploying a specific contract to all chains:
  python3 script_name.py -c PeanutV4

Notice: you have to update CONTRACTS_MAPPING and foundry.toml for this script to work.
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
