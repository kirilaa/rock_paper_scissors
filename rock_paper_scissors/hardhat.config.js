require("@nomiclabs/hardhat-waffle");
require('dotenv').config();
require("@nomiclabs/hardhat-etherscan");



module.exports = {
  solidity: "0.8.20",
  paths: {
    sources: "./src",
    artifacts: "./artifacts"
  },
  networks: {
    goerli: {
      url: `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: "P546M5MV5CJ81UVHK1AHF96GRMFM1585JT"
  }
};