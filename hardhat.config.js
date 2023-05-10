/** @type import('hardhat/config').HardhatUserConfig */
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require("hardhat-contract-sizer");
require("solidity-coverage");
require("dotenv").config();
const { utils } = require("ethers");

module.exports = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            forking: {
                url: `https://mainnet.infura.io/v3/${process.env.PROJECT_INFURA_ID}`,
                blockNumber: 16575450,
            },
        },
        mainnet: {
            url: `https://mainnet.infura.io/v3/${process.env.PROJECT_INFURA_ID}`,
            chainId: 1,
            gasPrice: utils.parseUnits("100", "gwei").toNumber(),
            accounts: [process.env.DEPLOYER_WALLET],
        },
        bsc_mainnet: {
            url: "https://bsc-dataseed.binance.org/",
            chainId: 56,
            gasPrice: utils.parseUnits("100", "gwei").toNumber(),
            accounts: [process.env.DEPLOYER_WALLET],
        },
        bsc_testnet: {
            url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
            chainId: 97,
            gasPrice: utils.parseUnits("100", "gwei").toNumber(),
            accounts: [process.env.DEPLOYER_WALLET],
        },
    },
    solidity: {
        compilers: [
            {
                version: "0.8.19",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 2000,
                    },
                },
            },
        ],
    },
};
