import { deployContract } from "./utils";

// An example of a basic deploy script
// It will deploy the specified contract to the selected network
// as well as verify it on Block Explorer if possible for the network
export default async function () {
  const contractArtifactName = "contracts/V4/PeanutV4.3.sol:PeanutV4";

  // eco is not deployed on zksync era, so using 0x00..00 for eco address
  const constructorArguments = ["0x0000000000000000000000000000000000000000"];

  await deployContract(contractArtifactName, constructorArguments);
}
