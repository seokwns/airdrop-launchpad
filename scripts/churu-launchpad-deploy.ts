import { ethers } from "hardhat";

const { PRIVATE_KEY } = process.env;

async function main() {
  const churuLaunchpad = await ethers.deployContract("ChuruLaunchpad", ["0xbD079ed7e48B89d64A23D57A9A75f29174907BDD"]);
  await churuLaunchpad.waitForDeployment();

  console.log();
  console.log(`ChuruLaunchpad deployed to: ${churuLaunchpad.target}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
