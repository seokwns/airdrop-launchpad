import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import 'dotenv/config';

const { ETHERSCAN_KEY, PRIVATE_KEY } = process.env;

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.5.17',
      },
      {
        version: '0.8.24',
      },
    ],
  },
  networks: {
    baobab: {
      chainId: 1001,
      url: 'https://public-en-baobab.klaytn.net',
      gasPrice: 25000000000,
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
    },
    cypress: {
      chainId: 8217,
      url: 'https://public-en-cypress.klaytn.net',
      gasPrice: 250000000000,
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
    },
    endurance: {
      url: 'http://20.197.13.207:8545',
      chainId: 648,
      accounts: [PRIVATE_KEY!],
    },
  },
  etherscan: {
    apiKey: {
      baobab: ETHERSCAN_KEY !== undefined ? ETHERSCAN_KEY : '',
      cypress: ETHERSCAN_KEY !== undefined ? ETHERSCAN_KEY : '',
    },
    customChains: [
      {
        network: 'baobab',
        chainId: 1001,
        urls: {
          apiURL: 'https://api-baobab.klaytnscope.com/api',
          browserURL: 'https://baobab.klaytnscope.com',
        },
      },
      {
        network: 'cypress',
        chainId: 8217,
        urls: {
          apiURL: 'https://api-cypress.klaytnscope.com/api',
          browserURL: 'https://klaytnscope.com',
        },
      },
      {
        network: 'endurance',
        chainId: 648,
        urls: {
          apiURL: 'https://explorer-endurance.fusionist.io/api',
          browserURL: 'https://explorer-endurance.fusionist.io',
        },
      },
    ],
  },
  sourcify: {
    enabled: false,
  },
};

export default config;
