require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.11",
  networks: {
    goerli: {
      url: '',
      chainId: 5,
      gas: 'auto',
      gasPrice: 'auto',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    bsc: {
      url: "https://bsc-dataseed2.binance.org/",
      chainId: 56,
      gas: 'auto',
      gasPrice: 'auto',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    eth: {
      url: "",
      chainId: 1,
      gas: 'auto',
      gasPrice: 'auto',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    polygon: {
      url: "",
      chainId: 137,
      gas: 'auto',
      gasPrice: 'auto',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    avax: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      chainId: 43114,
      gas: 'auto',
      gasPrice: 'auto',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    mumbai: {
      url: "https://polygontestapi.terminet.io/rpc",
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
      gas: 'auto',
      gasPrice: 'auto',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    sand_verse: {
      url: "https://rpc.sandverse.oasys.games",
      chainId: 20197,
      gas: 'auto',
      gasPrice: 'auto',
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
      chainId: 9372,
      gas: 'auto',
      gasPrice: 'auto',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
    saakuru: {
      url: "https://rpc.saakuru.network",
      chainId: 7225878,
      gasPrice: 'auto',
      accounts: [process.env.DEPLOYER_PRIVATE_KEY || '']
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_APIKEY,
  }
};
