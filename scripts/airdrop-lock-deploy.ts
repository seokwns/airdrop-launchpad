import { ethers } from "hardhat";

const { PRIVATE_KEY } = process.env;

async function main() {
  const [deployer] = await ethers.getSigners();

  const testToken = await ethers.deployContract("TestToken", ["Test Token", "TST"]);
  await testToken.waitForDeployment();
  await testToken.mint(deployer.address, ethers.parseEther("10000000"));

  const _startTimestamp = Math.floor(Date.now() / 1000) + 60;
  const _endTimestamp = _startTimestamp + 60 * 60 * 24 * 7;
  const _lockupPeriod = 60 * 60 * 24 * 30 * 3;
  const _immediateClaimPercentage = 2500;
  const airdropLock = await ethers.deployContract("AirdropLock", [
    testToken.target,
    _startTimestamp,
    _endTimestamp,
    _lockupPeriod,
    _immediateClaimPercentage,
  ]);

  await airdropLock.waitForDeployment();
  console.log();
  console.log("AirdropLock deployed to:", airdropLock.target);
  console.log(testToken.target);
  console.log(_startTimestamp);
  console.log(_endTimestamp);
  console.log(_lockupPeriod);
  console.log(_immediateClaimPercentage);

  await testToken.transfer(airdropLock.target, ethers.parseEther("10000000"));

  console.log();
  console.log("Done.");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
