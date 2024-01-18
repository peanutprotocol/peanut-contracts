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
 forge test --match-path test/V4/testX** -vvvv
```

Test on Fork:
```bash
 forge test --fork-url "https://ethereum-goerli.publicnode.com" --match-path test/V4/testWithdrawDepositXChain** -vvvv
```

## Deploy

Use `deploy.py` for simplicity.
Alternatively: `forge create...` or `forge script`

## Run a script

e.g. (optional params)

```bash
forge script script/DeployEthRome.s.sol:DeployEthRome --rpc-url optimism-goerli --broadcast --verify -vvvv --legacy
```

## Other useful commands

e.g. verify contract:
    
```bash
    forge verify-contract 0x690481ce72b1080bd928a35a0ecf329be902cd6a src/V4/PeanutV4.2.sol:PeanutV4 --watch --chain base
    forge verify-contract 0xBF9688FF5302Ad722343140cEd16EBE30db86c25 src/V4/PeanutRouter.sol:PeanutV4Router --watch --chain polygon
```