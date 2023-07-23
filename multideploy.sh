# Run the following commands:
# load .env
source .env

# deploy on goerli
forge script script/PeanutV4.s.sol:DeployScript --rpc-url goerli --broadcast --verify -vvvv
forge script script/PeanutV4.s.sol:DeployScript --rpc-url goerli --etherscan-api-key goerli --broadcast --verify -vvvv
# 0x0e16cd9de31dc2fbd58f1cff09b6e380c4368f95

# deploy on mainnet

# deploy on Gnosis Chain

# deploy on gnosis chain testnet
forge script script/PeanutV4.s.sol:DeployScript --rpc-url gnosis-testnet --broadcast -vvvv 


# Deploy on Starknet

# deploy on Starknet testnet
# not evm (not gonna write cairo)

# deploy on Mantle

# deploy on Mantle testnet
# doesn't support eip-1559, have to add --legacy
forge script script/PeanutV4.s.sol:DeployScript --rpc-url mantle-testnet --broadcast --verify -vvvv --legacy
# 0x7B36e10AA3ff44576efF4b1AfB80587B9b3BA3a5
# https://explorer.testnet.mantle.xyz/address/0x7B36e10AA3ff44576efF4b1AfB80587B9b3BA3a5

# deploy on Celo

# deploy on Celo testnet
forge script script/PeanutV4.s.sol:DeployScript --rpc-url celo-alfajores --broadcast -vvvv
# 0x8d1a17A3A4504aEB17515645BA8098f1D75237f7
# https://explorer.celo.org/alfajores/address/0x8d1a17A3A4504aEB17515645BA8098f1D75237f7


# deploy on Neon EVM

# deploy on Neon EVM testnet
forge script script/PeanutV4.s.sol:DeployScript --rpc-url neon-devnet --broadcast -vvvv --legacy

# deploy on ZetaChain

# deploy on ZetaChain testnet
forge script script/PeanutV4.s.sol:DeployScript --rpc-url zetachain-testnet --broadcast -vvvv
# 0xABCf92BD1c01f2eFe63FfcEaa73F19ec72F0Eba5

# deploy on polygon zkEVM

# deploy on polygon zkEVM testnet
forge script script/PeanutV4.s.sol:DeployScript --rpc-url polygon-zkevm-testnet --etherscan-api-key polygon-zkevm-testnet --broadcast --verify -vvvv
# https://testnet-zkevm.polygonscan.com/address/0x60d5db92eca3ee10ccf60517f910d8154ff62231

# deploy on filecoin testnet
forge script script/PeanutV4.s.sol:DeployScript --rpc-url filecoin-testnet --broadcast -vvvv




### OPTIONAL ### 

# deploy on Arbitrum

# deploy on Arbitrum testnet

# deploy on Optimism

# deploy on Optimism testnet

