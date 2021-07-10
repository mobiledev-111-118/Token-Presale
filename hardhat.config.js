/**
 * @type import('hardhat/config').HardhatUserConfig
 */
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-ethers');
require('@nomiclabs/hardhat-etherscan');

const {alchemyKey, ringkebyPrivateKey} = require("./secrets.json");

task('accounts', 'Prints the list of accounts', async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

module.exports = {
  defaultNetwork: "rinkeby",
  networks: {
		localhost: {
			url: 'http://127.0.0.1:8545',
		},
		hardhat: {},
    mainnet: {
      url: `https://eth-rinkeby.alchemyapi.io/v2/${alchemyKey}`,
      accounts: [`0x${ringkebyPrivateKey}`]
    },
    rinkeby: {
      url: `https://eth-rinkeby.alchemyapi.io/v2/${alchemyKey}`,
      accounts: [`0x${ringkebyPrivateKey}`]
    }
  },
  solidity: {
    version: '0.8.0',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
    },
  },
  paths: {
    sources: './contracts',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts',
  },
  mocha: {
    timeout: 2000000,
  },
};
  