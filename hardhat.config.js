/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 require('@nomiclabs/hardhat-waffle');
 require('@nomiclabs/hardhat-ethers');
 require('@nomiclabs/hardhat-etherscan');

task('accounts', 'Prints the list of accounts', async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const RINKEBY_PRIVATE_KEY = "af2430978e0a943c0d5af4e2e6c4ba367ec104da4c922bb0aaa62cdf96cac78d"
const ALCHEMY_API_KEY = "UoMpkv14SqLdS_O1OK_L9WkBngmMpSQ7"


module.exports = {
  networks: {
		localhost: {
			url: 'http://127.0.0.1:8545',
		},
		hardhat: {},
    mainnet: {
      url: `https://eth-rinkeby.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
      accounts: [`0x${RINKEBY_PRIVATE_KEY}`]
		},
    rinkeby: {
      url: `https://eth-rinkeby.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
      accounts: [`0x${RINKEBY_PRIVATE_KEY}`]
    }
  },
  solidity: {
    version: '0.8.0',
    settings: {
      optimizer: {
        enabled: true,
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
  