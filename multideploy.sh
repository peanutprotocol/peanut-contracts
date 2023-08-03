source .env

### mainnet

# mainnet-goerli
forge script script/PeanutV4.s.sol:DeployScript --rpc-url goerli --broadcast --verify -vvvv
forge script script/PeanutV4.s.sol:DeployScript --rpc-url goerli --etherscan-api-key goerli --broadcast --verify -vvvv
# 0x0e16cd9de31dc2fbd58f1cff09b6e380c4368f95
# https://goerli.etherscan.io/address/0x0e16cd9de31dc2fbd58f1cff09b6e380c4368f95#code


### polygon
forge script script/PeanutV4.s.sol:DeployScript --rpc-url polygon --etherscan-api-key polygon --broadcast --verify -vvvv --legacy

# polygon mumbai
forge script script/PeanutV4.s.sol:DeployScript --rpc-url polygon-mumbai --etherscan-api-key polygon --broadcast --verify -vvvv --legacy


### Optimism
forge script script/PeanutV4.s.sol:DeployScript --rpc-url optimism --etherscan-api-key optimism --broadcast --verify -vvvv
# Optimism testnet
forge script script/PeanutV4.s.sol:DeployScript --rpc-url optimism-goerli --etherscan-api-key optimism --broadcast --verify -vvvv


### Gnosis Chain

# gnosis chain testnet
forge script script/PeanutV4.s.sol:DeployScript --rpc-url gnosis-testnet --broadcast -vvvv 
# 0xABCf92BD1c01f2eFe63FfcEaa73F19ec72F0Eba5
# https://gnosis-chiado.blockscout.com/address/0xABCf92BD1c01f2eFe63FfcEaa73F19ec72F0Eba5


### Mantle

# Mantle testnet
# doesn't support eip-1559, have to add --legacy
forge script script/PeanutV4.s.sol:DeployScript --rpc-url mantle-testnet --broadcast --verify -vvvv --legacy
# 0x7B36e10AA3ff44576efF4b1AfB80587B9b3BA3a5
# https://explorer.testnet.mantle.xyz/address/0x7B36e10AA3ff44576efF4b1AfB80587B9b3BA3a5


### Celo

# Celo testnet
forge script script/PeanutV4.s.sol:DeployScript --rpc-url celo-alfajores --broadcast -vvvv
# 0x8d1a17A3A4504aEB17515645BA8098f1D75237f7
# https://explorer.celo.org/alfajores/address/0x8d1a17A3A4504aEB17515645BA8098f1D75237f7


### Neon EVM

# Neon EVM testnet
forge script script/PeanutV4.s.sol:DeployScript --rpc-url neon-devnet --broadcast -vvvv --legacy -g 8000
# 0x8d1a17A3A4504aEB17515645BA8098f1D75237f7
# https://devnet.neonscan.org/address/0x8d1a17A3A4504aEB17515645BA8098f1D75237f7


### ZetaChain

# ZetaChain testnet
forge script script/PeanutV4.s.sol:DeployScript --rpc-url zetachain-testnet --broadcast -vvvv
# 0xABCf92BD1c01f2eFe63FfcEaa73F19ec72F0Eba5
# https://athens3.explorer.zetachain.com/address/0xABCf92BD1c01f2eFe63FfcEaa73F19ec72F0Eba5


### polygon zkEVM

# polygon zkEVM testnet
forge script script/PeanutV4.s.sol:DeployScript --rpc-url polygon-zkevm-testnet --etherscan-api-key polygon-zkevm-testnet --broadcast --verify -vvvv
# 0x60d5db92eca3ee10ccf60517f910d8154ff62231
# https://testnet-zkevm.polygonscan.com/address/0x60d5db92eca3ee10ccf60517f910d8154ff62231


### Filecoin FVM
# filecoin testnet
forge script script/PeanutV4.s.sol:DeployScript --rpc-url filecoin-testnet --broadcast -vvvv
# 0x1851359AB8B002217cf4D108d7F027B63563754C
# https://calibration.filfox.info/en/address/0x1851359AB8B002217cf4D108d7F027B63563754C


### zkSync

# zkSync testnet
forge script script/PeanutV4.s.sol:DeployScript --rpc-url zksync-testnet --broadcast -vvvv
# got stuck on https://github.com/omurovec/foundry-zksync-era
# https://goerli.explorer.zksync.io/
# contract address will be at 0x8d1a17A3A4504aEB17515645BA8098f1D75237f7 once fixed


### Base
forge script script/PeanutV4.s.sol:DeployScript --rpc-url base --etherscan-api-key base --broadcast --verify -vvvv

### Base testnet
forge script script/PeanutV4.s.sol:DeployScript --rpc-url base-testnet --etherscan-api-key base-testnet --broadcast --verify -vvvv
forge script script/PeanutV4.s.sol:DeployScript --rpc-url base --etherscan-api-key base --broadcast --verify -vvvv


### Milkomeda C1
forge script script/PeanutV4.s.sol:DeployScript --rpc-url milkomeda-c1 --broadcast --verify -vvvv --legacy


# Milkomeda C1 Testnet
forge script script/PeanutV4.s.sol:DeployScript --rpc-url milkomeda-c1-testnet --broadcast --verify -vvvv --legacy



############################################

# verify existing
forge verify-contract \
    --chain-id 8453 \
    --num-of-optimizations 200 \
    --watch \
    -e "Y56JD8HMC2K5MQFID84PF6MSEE81TKDFRR" \
    --compiler-version "v0.8.20" \
    "0x1851359ab8b002217cf4d108d7f027b63563754c" \
    "src/archive/V3/PeanutV3.sol:PeanutV3"

forge verify-contract 0x1851359ab8b002217cf4d108d7f027b63563754c --rpc-url base --etherscan-api-key base --verify -vvvv

############################################
### Non EVMS

### Starknet

# Starknet testnet
# not evm (not gonna write cairo)
