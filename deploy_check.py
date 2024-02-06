import json
from deploy import CONTRACTS_MAPPING  # Import the CONTRACTS_MAPPING from deploy.py

CONTRACTS_JSON_PATH = "contracts.json"

def load_contracts_json():
    with open(CONTRACTS_JSON_PATH, "r") as file:
        return json.load(file)

def get_expected_versions():
    # Extract the short contract names (e.g., "v3", "v4") from CONTRACTS_MAPPING
    return set(CONTRACTS_MAPPING.values())

def categorize_chains(contracts_json):
    mainnets, testnets = {}, {}
    for chain_id, contracts in contracts_json.items():
        if contracts.get("mainnet") == "true":
            mainnets[chain_id] = contracts
        else:
            testnets[chain_id] = contracts
    return mainnets, testnets

def check_missing_deployments(contracts_json, expected_versions):
    missing_deployments = {version: {"mainnets": [], "testnets": []} for version in expected_versions}
    mainnets, testnets = categorize_chains(contracts_json)

    for category, chains in [("mainnets", mainnets), ("testnets", testnets)]:
        for chain_id, contracts in chains.items():
            deployed_versions = set(contracts.keys()) - {"name", "mainnet"}
            missing_versions = expected_versions - deployed_versions
            for version in missing_versions:
                missing_deployments[version][category].append(contracts.get("name", f"Chain ID {chain_id}"))

    return missing_deployments

def print_missing_deployments(missing_deployments):
    print("Mainnets:\nMissing Deployments")
    for version, info in missing_deployments.items():
        if info["mainnets"]:
            print(f"{version} : {', '.join(info['mainnets'])}")

    print("\nTestnets:\nMissing Deployments")
    for version, info in missing_deployments.items():
        if info["testnets"]:
            print(f"{version} : {', '.join(info['testnets'])}")

def main():
    contracts_json = load_contracts_json()
    expected_versions = get_expected_versions()
    missing_deployments = check_missing_deployments(contracts_json, expected_versions)
    print_missing_deployments(missing_deployments)

if __name__ == "__main__":
    main()