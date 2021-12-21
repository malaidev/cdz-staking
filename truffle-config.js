const HDWalletProvider = require('@truffle/hdwallet-provider');
require('dotenv').config();
// const fs = require('fs');
// const mnemonic = fs.readFileSync('.secret').toString().trim();

module.exports = {
  networks: {
    development: {
      host: '127.0.0.1', 
      port: 9545, 
      network_id: '*', 
    },
    //  mumbai: {
    //    provider: () =>
    //      new HDWalletProvider(
    //        mnemonic,
    //        'https://polygon-mumbai.infura.io/v3/',
    //      ),
    //    network_id: 80001,
    //    gas: 5500000,
    //    confirmations: 2,
    //    timeoutBlocks: 200,
    //    skipDryRun: true,
    //  },
    // bsctestnet: {
    //   provider: () =>
    //     new HDWalletProvider(
    //       mnemonic,
    //       `https://data-seed-prebsc-1-s2.binance.org:8545`,
    //     ),
    //   network_id: 97,
    //   confirmations: 10,
    //   timeoutBlocks: 200,
    //   networkCheckTimeout: 100000000,
    //   skipDryRun: true,
    // },
  },

  compilers: {
    solc: {
      version: '0.8.7',
      settings: {
        optimizer: {
          enabled: false,
          runs: 200,
        },
      },
    },
  },

  plugins: ['truffle-plugin-verify'],

  api_keys: {
    etherscan: ''
  }
};
