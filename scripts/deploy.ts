import { ethers } from 'hardhat';

interface AirdropInfo {
  address: string;
  token: string;
  startTimestamp: number;
  endTimestamp: number;
  tgePercent: number;
  vestingCount: number;
}

interface AirdropData {
  address: string;
  amount: number;
  claimedAmount: number;
  claimIdex: number;
}

async function main() {
  // CONSTANTS
  const airdropToken = '0x07a454A077Da71787fAA8A2f22702e9eF7EE6360';

  // Deployer account info
  const deployer = await ethers.getSigner(process.env.DEPLOYER!);
  console.log(`Deploying contracts with the account: ${deployer.address}`);
  console.log(`Account balance: ${ethers.formatEther(await deployer.provider.getBalance(deployer.address))}`);

  /**
   * Deploy AirdropToken contract
   */
  // const deployAirdropFactory = await ethers.deployContract('AirdropFactory');
  // console.log(`AirdropFactory address: ${deployAirdropFactory.target}`);

  /**
   * Load airdrop factory contract
   */
  const airdropFactory = await ethers.getContractAt('AirdropFactory', '0x74488A17A82a669D8B2c93b83bF3D4D924fd990c');

  /**
   * Create a new airdrop
   */
  // const now = new Date();
  // const startTimestamp = Math.floor(now.getTime() / 1000);
  // const endTimestamp = Math.floor(new Date().setMinutes(now.getMinutes() + 12) / 1000);

  // await airdropFactory.createAirdrop(airdropToken, startTimestamp, endTimestamp, 30, 3, {
  //   gasLimit: 10000000,
  //   gasPrice: 100000000,
  // });

  /**
   * Load airdrop contract
   */
  const airdrop = await ethers.getContractAt('Airdrop', '0xd7c9dcb3080a681be699e23a13f7351ce53a2d45');

  // /**
  //  * Insert airdrop data
  //  */
  // await airdrop.insertAirdropData('0x63cac65c5eb17E6Dd47D9313e23169f79d1Ab058', ethers.parseEther('100'), {
  //   gasLimit: 1000000,
  //   gasPrice: 10000000,
  // });

  /**
   * Batch insert airdrop data
   */
  console.log('Batch insert airdrop data');
  await airdrop.batchInsertAirdropData(
    [
      '0xe4E61ce60c53A2B6b08d81d1445bEdF7F90f3FE6',
      '0xcA62094677bCBB691317D08F481855DEc3846f92',
      '0xF783145cf9cb337e1017EA65C6AFd7d8fdB04e6C',
    ],
    [ethers.parseEther('300'), ethers.parseEther('200'), ethers.parseEther('100')],
    {
      gasLimit: 1000000,
      gasPrice: 10000000,
    }
  );

  /**
   * Get airdrop data from factory
   */
  // console.log();
  // console.log('Get airdrop data from factory');
  // const factoryAirdropData = await airdropFactory.airdropInfo(1);
  // console.log(`Airdrop data: ${factoryAirdropData}`);

  // console.log();
  // console.log('Get all airdrop data from factory');
  // const allFactoryAirdropData = (await airdropFactory.getAllAirdrops()) as unknown as AirdropInfo[];
  // allFactoryAirdropData.forEach((data, index) => {
  //   console.log(`Airdrop ${index + 1}: ${data}`);
  // });

  /**
   * Get total airdrop amount
   */
  // console.log();
  // console.log('get total airdrop amount');
  // const totalAirdropAmount = await airdrop.totalAirdropAmount();
  // console.log(`total airdrop amount: ${ethers.formatEther(totalAirdropAmount)}`);

  /**
   * Get airdrop data
   */
  // console.log();
  // console.log('Get account airdrop data');
  // const airdropData = await airdrop.airdropData(1);
  // console.log(`Airdrop data: ${airdropData as unknown as AirdropData}`);

  /**
   * Get claimable amount
   */
  // console.log();
  // console.log('Get claimable amount');
  // const claimableAmount = await airdrop.getClaimableAmount('0x63cac65c5eb17E6Dd47D9313e23169f79d1Ab058');
  // console.log(`Claimable amount: ${ethers.formatEther(claimableAmount)}`);

  /**
   * Claim airdrop
   */
  // console.log();
  // console.log('airdrop claim');
  // await airdrop.claim({
  //   gasLimit: 1000000,
  //   gasPrice: 10000000,
  // });

  /**
   * Get fully claimed accounts
   */
  // console.log();
  // console.log('Get fully claimed accounts');
  // const accountData = (await airdrop.getFullyClaimedAccounts()) as unknown as AirdropData[];
  // accountData.forEach((data, index) => {
  //   console.log(`Account ${index + 1}: ${data}`);
  // });

  /**
   * Get airdrop data length
   */
  console.log('Get airdrop data length');
  const airdropDataLength = await airdrop.dataLength();
  console.log(`Airdrop data length: ${airdropDataLength}`);

  /**
   * Get all airdrop data
   */
  console.log('Get all airdrop data');
  for (let i = 1; i <= airdropDataLength; i++) {
    const data = await airdrop.airdropData(i);
    console.log(`Airdrop ${i}: ${data}`);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
