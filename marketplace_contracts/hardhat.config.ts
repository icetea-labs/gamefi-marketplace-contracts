import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
require('dotenv').config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.4.23",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1500
      }
    }
  },
  networks: {
    bscTestnet: {
      url: "",
      gas: 2100000,
      gasPrice: 18000000000,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    mumbai: {
      url: "https://polygontestapi.terminet.io/rpc",
      gas: 'auto',
      gasPrice: 'auto',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    goerli: {
      url: "",
      gas: 'auto',
      gasPrice: 'auto',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    bsc: {
      url: "https://bsc-dataseed2.binance.org/",
      gas: 'auto',
      gasPrice: 'auto',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    eth: {
      url: "",
      gas: 'auto',
      gasPrice: 'auto',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    polygon: {
      url: "https://rpc-mainnet.maticvigil.com/",
      gas: 'auto',
      gasPrice: 'auto',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    avax: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      gas: 'auto',
      gasPrice: 'auto',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    oasys: {
      url: "https://rpc.mainnet.oasys.games",
      chainId: 248,
      gas: 'auto',
      gasPrice: 'auto',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    oasys_testnet: {
      url: "https://rpc.testnet.oasys.games",
      chainId: 9372,
      gasPrice: 20000000000,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    sand_verse: {
      url: "https://rpc.sandverse.oasys.games",
      chainId: 20197,
      gasPrice: 20000000000,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    mch: {
      url: "https://rpc.oasys.mycryptoheroes.net",
      gas: 'auto',
      gasPrice: 'auto',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    tcg: {
      url: "https://rpc.tcgverse.xyz",
      chainId: 2400,
      gas: 'auto',
      gasPrice: 'auto',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    saakuru_verse: {
      url: "https://rpc.saakuru.network",
      chainId: 7225878,
      gas: 'auto',
      gasPrice: 'auto',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_APIKEY,
  },
};

export default config;
