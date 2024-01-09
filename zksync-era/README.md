# Peanut on zksync era via hardhat

## Steps to deploy peanut on zksync era

1. `yarn install`
2. Copy relevant contracts from the normal `src` directory to the `contracts` directory in the `zksync-era` folder. Important: try to copy only the minimum files that are needed for the deployment, otherwise you may reference some unrelated dependencies which will be difficult to install.
3. `yarn compile`
4. Make a deployment script in `deploy` directory in the `zksync-era` folder.
5. `npx hardhat deploy-zksync --script <yourScript.ts>`
6. Take the address and copy-paste it in `contracts.json`.
