import { ethers } from "hardhat";

async function main() {
  const contract = await ethers.deployContract("ChuruTokenSale", ["0xbD079ed7e48B89d64A23D57A9A75f29174907BDD"]);
  await contract.waitForDeployment();

  console.log();
  console.log(`ChuruLaunchpad deployed to: ${contract.target}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
