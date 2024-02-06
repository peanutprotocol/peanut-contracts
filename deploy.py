import os
import json
import subprocess
from typing import List, Tuple
import argparse
import toml
import dotenv
import time

dotenv.load_dotenv()

# Load the foundry.toml file
config = toml.load("foundry.toml")

# Definitions
CONTRACTS_MAPPING = {
    "PeanutV3": "v3",
    "PeanutV4.1": "v4",
    "PeanutV4.2": "v4.2",
    "PeanutV4.3": "v4.3",
    "PeanutBatcherV4": "Bv4",
    "PeanutBatcherV4.2": "Bv4.2",
    "PeanutBatcherV4.3": "Bv4.3",
    "PeanutV4Router": "Rv4.2"
}
CONTRACTS = list(CONTRACTS_MAPPING.keys())
CONTRACTS_JSON_PATH = "contracts.json"


def has_etherscan_key(chain: str) -> bool:
    return chain in config["etherscan"]


def run_command(command: str) -> str:
    print(f"== Running command: ==\n{command}")
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
        assert (
            data["receipts"] and len(data["receipts"]) > 0
        )  # check that receipts exist
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
    try:
        output = run_command(command)

        # Define the maximum time (in seconds) and interval for retries
        max_time = 120
        retry_interval = 30
        attempts = max_time // retry_interval

        # Check if there's an Etherscan error
        while "Etherscan could not detect the deployment." in output and attempts > 0:
            print("Etherscan verification failed. Retrying without --broadcast flag...")
            time.sleep(retry_interval)
            command_without_broadcast = command.replace(
                "--broadcast", "", 1
            )  # replace only the first occurrence
            output = run_command(command_without_broadcast)
            attempts -= 1

        return output

    except subprocess.CalledProcessError as e:
        print(f"Command failed with error: {e}")
        return str(e)
    
def make_command(contract: str, chain: str, contracts_json: dict, broadcast: bool) -> str:
    # Existence of `contract` in CONTRACTS_MAPPING must be validated by the caller
    _, legacy = get_chain_info(chain)
    command = f"forge script script/{contract}.s.sol:DeployScript --rpc-url {config['rpc_endpoints'][chain]} --verify -vvvv"
    if legacy:
        command += " --legacy"
        print(f"Using legacy mode for {chain}")
    
    if broadcast:
        command += " --broadcast"
        print("Will broadcast transactions to the chain")

    return command


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
        if chain_id not in contracts_json:
            contracts_json[chain_id] = {}
        existing_address = contracts_json[chain_id].get(short_contract_name)
        if existing_address:
            # Show a warning
            print(
                f"Warning: Contract {short_contract_name} already exists for {chain} at address {existing_address}."
            )
            action = input("The contract is already deployed. Enter Y to redeploy, v to verify, and anything else to cancel: ")
            if action.lower() == "v":
                command = make_command(
                    contract=contract,
                    chain=chain,
                    contracts_json=contracts_json,
                    broadcast=False,
                )
                print(f"Verifying {contract} on {chain}")
                output = run_command(command)
                print(output)
                continue
            elif action.lower() != "y":
                print(
                    f"Skipped deploying & overwriting {contract} ({short_contract_name}) for {chain}."
                )
                continue  # Skip the rest of the loop and move to the next contract        
        
        command = make_command(
            contract=contract,
            chain=chain,
            contracts_json=contracts_json,
            broadcast=True,
        )

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
            try:
                deploy_to_chain(chain, contracts)
            except Exception as e:
                print(f"Error!!! {str(e)}")


def deploy_to_specific_chains(chains: List[str], contracts: List[str]):
    for chain in chains:
        if chain not in config["rpc_endpoints"]:
            print(f"Error: Unknown chain {chain}")
            continue
        try:
            deploy_to_chain(chain, contracts)
        except Exception as e:
            print(f"Error!!! {str(e)}")


def run_script_on_chain(chain: str, script: str):
    if not has_etherscan_key(chain):
        print(
            f"Error: foundry.toml does not include an etherscan verification key for {chain}"
        )
        return

    if chain not in config["rpc_endpoints"]:
        print(f"Error: foundry.toml rpc_endpoints does not include chain {chain}")
        return

    command = f"forge script {script} --rpc-url {config['rpc_endpoints'][chain]} --broadcast --verify -vvvv"
    print(f"Running script {script} on {chain}")
    output = run_command(command)
    print(output)

def main():
    epilog_text = """
Examples of using this script:

Help:
  python3 deploy.py -h

Deploy single contract on single chain:
  python3 deploy.py -c PeanutBatcherV4 -ch polygon-mumbai

Deploying Multiple Contracts to a Specific Chain:
  python3 deploy.py -c PeanutV3 PeanutV4 -ch goerli

Deploying Single Contract to a Multiple Chains:
  python3 deploy.py -c PeanutV3 PeanutV4 -ch goerli polygon-mumbai

Deploying a specific contract to all chains:
  python3 deploy.py -c PeanutV4

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
        nargs="+",
        type=str,
        help="Specify specific chains to deploy to. If not provided, will ask for all chains.",
    )
    parser.add_argument(
        "-s",
        "--script",
        type=str,
        help="Specify a script file to run on the chain.",
    )

    args = parser.parse_args()

    if args.script:
        if args.chain:
            for chain in args.chain:
                run_script_on_chain(chain, args.script)
        else:
            for chain in config["rpc_endpoints"].keys():
                user_input = input(f"Run script on {chain}? (y/n) ")
                if user_input == "y":
                    run_script_on_chain(chain, args.script)
    else:
        if args.chain:
            deploy_to_specific_chains(args.chain, args.contracts)
        else:
            deploy_to_all_chains(args.contracts)



if __name__ == "__main__":
    main()
