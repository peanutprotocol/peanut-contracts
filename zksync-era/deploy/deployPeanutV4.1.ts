import { deployContract } from "./utils";

// An example of a basic deploy script
// It will deploy the specified contract to the selected network
// as well as verify it on Block Explorer if possible for the network
export default async function () {
  const contractArtifactName = "contracts/V4/PeanutV4.1.sol:PeanutV4";
  const constructorArguments = [];

  await deployContract(contractArtifactName, constructorArguments);
}
