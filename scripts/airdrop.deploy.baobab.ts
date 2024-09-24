const { ethers } = require('hardhat');
import Caver from 'caver-js';
import 'dotenv/config';

const {
  KLAYTN_BAOBAB_URL,
  KLATYN_CYPRESS_URL,
  DEPLOYER = '',
  PRIVATE_KEY = '',
  TOKEN_ADDRESS = '',
  AIRDROP_ADDRESS = '',
} = process.env;

const caver = new Caver(KLAYTN_BAOBAB_URL);

async function main() {
  const deployer = await ethers.getSigner(DEPLOYER);
  const keyring = caver.wallet.keyring.createFromPrivateKey(PRIVATE_KEY);
  caver.wallet.add(keyring);

  console.log(`Deploying contracts with the account: ${deployer.address}`);
  console.log(`Account balance: ${(await deployer.provider.getBalance(DEPLOYER)).toString()}`);

  const tokenContract = await caver.kct.kip7.deploy(
    {
      name: 'AirDropToken',
      symbol: 'ADT',
      decimals: 18,
      initialSupply: '100000000000000000000000000',
    },
    keyring.address
  );

  console.log();
  console.log(`deploy token address: ${tokenContract._address}`);

  const now = new Date();
  const startTimestamp = Math.floor(now.getTime() / 1000);
  const endTimestamp = Math.floor(new Date().setDate(now.getDate() + 7) / 1000);

  const airdropContract = await ethers.deployContract('AirDrop', [
    tokenContract._address,
    startTimestamp,
    endTimestamp,
    30,
    3,
  ]);
  await airdropContract.waitForDeployment();

  console.log();
  console.log(tokenContract._address, startTimestamp, endTimestamp);
  console.log(`deploy airdrop address: ${airdropContract.target}`);

  const proxyContract = await ethers.deployContract('OssifiableProxy', [airdropContract.target, DEPLOYER, '0x']);
  await proxyContract.waitForDeployment();

  console.log();
  console.log(`deploy proxy address: ${proxyContract.target}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
