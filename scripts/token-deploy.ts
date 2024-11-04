import { ethers } from 'hardhat';

async function main() {
  const deployer = await ethers.getSigner(process.env.DEPLOYER!);
  console.log(`Deploying contracts with the account: ${deployer.address}`);
  console.log(`Account balance: ${ethers.formatEther(await deployer.provider.getBalance(deployer.address))}`);

  // console.log();
  // console.log('Deploying Token contract');
  // const tokenFactory = await ethers.deployContract('TestToken', ['Mark Token', 'MARK']);
  // console.log(`Token contract address: ${tokenFactory.target}`);

  const MARK_TOKEN = '0x07a454A077Da71787fAA8A2f22702e9eF7EE6360';
  const token = await ethers.getContractAt('TestToken', MARK_TOKEN);

  await token.mint('0x63cac65c5eb17E6Dd47D9313e23169f79d1Ab058', ethers.parseEther('1000'), {
    gasLimit: 1000000,
    gasPrice: 10000000,
  });
  await token.transfer('0xd7c9dcb3080a681be699e23a13f7351ce53a2d45', ethers.parseEther('1000'), {
    gasLimit: 1000000,
    gasPrice: 10000000,
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
