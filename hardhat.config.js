require('dotenv').config();
require('hardhat-deploy');
require('@nomicfoundation/hardhat-toolbox');

module.exports = {
  solidity: {
    version: '0.8.20',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    localhost: {
      url: 'http://127.0.0.1:8545',
    },
    sepolia: {
      url: `https://sepolia.infura.io/v3/YOUR-INFURA-PROJECT-ID`,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
    },
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
    },
    rewardSource: {
      default: 1, // can configure different accounts for different networks
    },
  },
};
