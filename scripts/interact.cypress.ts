import Caver, { AbiItem } from 'caver-js';
import 'dotenv/config';
import { ethers } from 'ethers';

const {
  KLAYTN_BAOBAB_URL,
  KLAYTN_CYPRESS_URL,
  PRIVATE_KEY = '',
  TOKEN_ADDRESS = '',
  AIRDROP_ADDRESS = '',
} = process.env;

const caver = new Caver(KLAYTN_CYPRESS_URL);

const abi = [
  {
    inputs: [
      {
        internalType: 'address',
        name: '_tokenAddress',
        type: 'address',
      },
      {
        internalType: 'uint256',
        name: '_startTimestamp',
        type: 'uint256',
      },
      {
        internalType: 'uint256',
        name: '_endTimestamp',
        type: 'uint256',
      },
    ],
    stateMutability: 'nonpayable',
    type: 'constructor',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: 'uint256',
        name: 'newEndTime',
        type: 'uint256',
      },
    ],
    name: 'AirdropEndTimeUpdated',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: 'uint256',
        name: 'newStartTime',
        type: 'uint256',
      },
    ],
    name: 'AirdropStartTimeUpdated',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'address',
        name: 'receiver',
        type: 'address',
      },
      {
        indexed: false,
        internalType: 'uint256',
        name: 'amount',
        type: 'uint256',
      },
    ],
    name: 'Claimed',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'address',
        name: 'previousOwner',
        type: 'address',
      },
      {
        indexed: true,
        internalType: 'address',
        name: 'newOwner',
        type: 'address',
      },
    ],
    name: 'OwnershipTransferred',
    type: 'event',
  },
  {
    inputs: [
      {
        internalType: 'address[]',
        name: '_address',
        type: 'address[]',
      },
      {
        internalType: 'uint256[]',
        name: '_amount',
        type: 'uint256[]',
      },
    ],
    name: 'batchInsertAirdropData',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'claim',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'address',
        name: '_address',
        type: 'address',
      },
    ],
    name: 'deleteAirdropData',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'endTimestamp',
    outputs: [
      {
        internalType: 'uint256',
        name: '',
        type: 'uint256',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'address',
        name: '_address',
        type: 'address',
      },
    ],
    name: 'getAirdropData',
    outputs: [
      {
        components: [
          {
            internalType: 'enum AirDrop.ClaimStatus',
            name: 'status',
            type: 'uint8',
          },
          {
            internalType: 'uint256',
            name: 'amount',
            type: 'uint256',
          },
        ],
        internalType: 'struct AirDrop.AirdropData',
        name: '',
        type: 'tuple',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'address',
        name: '_address',
        type: 'address',
      },
      {
        internalType: 'uint256',
        name: '_amount',
        type: 'uint256',
      },
    ],
    name: 'insertAirdropData',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'isEnded',
    outputs: [
      {
        internalType: 'bool',
        name: '',
        type: 'bool',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'isStarted',
    outputs: [
      {
        internalType: 'bool',
        name: '',
        type: 'bool',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'owner',
    outputs: [
      {
        internalType: 'address',
        name: '',
        type: 'address',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'startTimestamp',
    outputs: [
      {
        internalType: 'uint256',
        name: '',
        type: 'uint256',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'tokenInstance',
    outputs: [
      {
        internalType: 'contract IKIP7',
        name: '',
        type: 'address',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'address',
        name: 'newOwner',
        type: 'address',
      },
    ],
    name: 'transferOwnership',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'transferTokenToOnwer',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'address',
        name: '_address',
        type: 'address',
      },
      {
        components: [
          {
            internalType: 'enum AirDrop.ClaimStatus',
            name: 'status',
            type: 'uint8',
          },
          {
            internalType: 'uint256',
            name: 'amount',
            type: 'uint256',
          },
        ],
        internalType: 'struct AirDrop.AirdropData',
        name: '_airdropData',
        type: 'tuple',
      },
    ],
    name: 'updateAirdropData',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: '_endTimestamp',
        type: 'uint256',
      },
    ],
    name: 'updateEndTimestamp',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: '_startTimestamp',
        type: 'uint256',
      },
    ],
    name: 'updateStartTimestamp',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
];

async function main() {
  const keyring = caver.wallet.keyring.createFromPrivateKey(PRIVATE_KEY);
  caver.wallet.add(keyring);
  console.log('Deployer:', keyring.address);
  console.log();

  const airdrop = new caver.klay.Contract(abi as AbiItem[], AIRDROP_ADDRESS);
  const tokenInstance = new caver.kct.kip7(TOKEN_ADDRESS);

  airdrop.methods.getAirdropData(keyring.address).call((err: any, res: any) => {
    if (err) {
      console.error(err);
    } else {
      console.log(res);
    }
  });

  // airdrop.methods.claim().send({ from: keyring.address, gas: 25000000000 });

  // await tokenInstance.transfer(AIRDROP_ADDRESS, ethers.parseEther('1000').toString(), {
  //   from: keyring.address,
  // });

  // await tokenInstance.transfer(
  //   '0x31b1da5926a0159b0c369e6f15756e9c666011e7',
  //   ethers.parseEther('1').toString(),
  //   {
  //     from: keyring.address,
  //   }
  // );

  await tokenInstance.balanceOf(keyring.address).then((res) => {
    console.log('Balance:', res);
  });

  // await tokenInstance.balanceOf('0x31b1da5926a0159b0c369e6f15756e9c666011e7').then((res) => {
  //   console.log('Balance:', res);
  // });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
