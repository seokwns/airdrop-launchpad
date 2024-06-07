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

  // const tokenContract = await caver.kct.kip7.deploy(
  //   {
  //     name: 'AirDropToken',
  //     symbol: 'ADT',
  //     decimals: 18,
  //     initialSupply: '100000000000000000000000000',
  //   },
  //   keyring.address
  // );

  // console.log();
  // console.log(`deploy token address: ${tokenContract._address}`);

  const now = new Date();
  const end = new Date().setDate(now.getDate() + 7);

  const airdropContract = await ethers.deployContract('AirDropFactory');
  await airdropContract.waitForDeployment();

  console.log();
  // console.log(tokenContract._address, Number(now), Number(end));
  console.log(`deploy airdrop factory address: ${airdropContract.target}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
