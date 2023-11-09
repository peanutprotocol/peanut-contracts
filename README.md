# Peanut Protocol

Repo for peanut smart contracts

Foundry reference: https://book.getfoundry.sh/getting-started/first-steps

## Deployments

See list of deployed contracts on `contracts.json`
See `deploy.py` for deploying more

## Install

```bash
forge install
```

## Test

```bash
forge test
```

Single test:
```bash
 forge test --match-path test/V5/testX** -vvvv
```

Test on Fork:
```bash
 forge test --fork-url "https://ethereum-goerli.publicnode.com" --match-path test/V5/testWithdrawDepositXChain** -vvvv
```

## Deploy

Use `deploy.py` for simplicity.
Alternatively: `forge create...` or `forge script`

## Run a script

e.g. (optional params)

```bash
forge script script/DeployEthRome.s.sol:DeployEthRome --rpc-url optimism-goerli --broadcast --verify -vvvv --legacy
```
