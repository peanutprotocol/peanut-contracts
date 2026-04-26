/**
 * One-shot Peanut V4.3 deploy to Arbitrum Sepolia (chainId 421614).
 *
 * Constructor arg: ecoAddress = 0x0 (no ECO support on Sepolia).
 * Deployer:        HARNESS_WALLET_PRIVATE_KEY (already funded via faucet).
 *
 * Run:
 *     cd peanut-contracts
 *     ~/.local/bin/solc --bin --abi --optimize --optimize-runs 99999 \
 *         --allow-paths . @openzeppelin/=lib/openzeppelin-contracts/ \
 *         -o build-v43 --overwrite src/V4/PeanutV4.3.sol
 *     PRIVATE_KEY=<harness-pk> node deploy-arb-sepolia.mjs
 */

import { readFileSync } from 'node:fs'
import { createPublicClient, createWalletClient, http, encodeDeployData, parseAbi } from 'viem'
import { arbitrumSepolia } from 'viem/chains'
import { privateKeyToAccount } from 'viem/accounts'

const RPC = process.env.RPC_URL || 'https://sepolia-rollup.arbitrum.io/rpc'
const PK = process.env.PRIVATE_KEY
if (!PK || !PK.startsWith('0x')) throw new Error('PRIVATE_KEY env var required (0x-prefixed)')

const abi = JSON.parse(readFileSync('build-v43/PeanutV4.abi', 'utf8'))
const bytecode = '0x' + readFileSync('build-v43/PeanutV4.bin', 'utf8').trim()

const account = privateKeyToAccount(PK)
const publicClient = createPublicClient({ chain: arbitrumSepolia, transport: http(RPC) })
const walletClient = createWalletClient({ account, chain: arbitrumSepolia, transport: http(RPC) })

const [balance, nonce] = await Promise.all([
	publicClient.getBalance({ address: account.address }),
	publicClient.getTransactionCount({ address: account.address }),
])
console.log(`deployer: ${account.address}`)
console.log(`balance:  ${balance} wei (${Number(balance) / 1e18} ETH)`)
console.log(`nonce:    ${nonce}`)
if (balance === 0n) throw new Error('deployer EOA has 0 ETH — refill from https://faucet.quicknode.com/arbitrum/sepolia')

const data = encodeDeployData({ abi, bytecode, args: ['0x0000000000000000000000000000000000000000'] })
console.log(`bytecode size: ${(bytecode.length - 2) / 2} bytes`)

const hash = await walletClient.deployContract({
	abi,
	bytecode,
	args: ['0x0000000000000000000000000000000000000000'],
})
console.log(`deploy tx: ${hash}`)
console.log(`waiting for inclusion...`)

const receipt = await publicClient.waitForTransactionReceipt({ hash, timeout: 120_000 })
if (receipt.status !== 'success') {
	console.error('deploy reverted:', receipt)
	process.exit(1)
}
console.log(`✓ deployed at: ${receipt.contractAddress}`)
console.log(`  block:        ${receipt.blockNumber}`)
console.log(`  gas used:     ${receipt.gasUsed}`)
console.log(`  arbiscan:     https://sepolia.arbiscan.io/address/${receipt.contractAddress}`)

// Quick sanity probe — depositCount() should equal 0 on a fresh deploy.
// (Contract uses `deposits.length` — read via getDepositCount in v4 family.)
try {
	const deposits = await publicClient.readContract({
		address: receipt.contractAddress,
		abi: parseAbi(['function getDepositCount() view returns (uint256)']),
		functionName: 'getDepositCount',
	})
	console.log(`  initial deposit count: ${deposits} (expected 0)`)
} catch (e) {
	console.log(`  (skipped depositCount probe: ${e.shortMessage ?? e.message})`)
}

console.log('\nNext: wire the address into peanut-api-ts/src/onchain/peanut/contracts.ts:')
console.log(`    '421614': { 'v4.3': '${receipt.contractAddress}' }`)
