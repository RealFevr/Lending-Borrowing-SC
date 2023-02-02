const { expect } = require('chai');
const { ethers } = require('hardhat');
const { constants } = require('@openzeppelin/test-helpers');

const { uniswap_abi } = require('../external_abi/uniswap.abi.json');
const { erc20_abi } = require('../external_abi/erc20.abi.json');

const { deploy } = require('../scripts/utils');

describe ("Lending-Borrowing Protocol test", function () {
    let daiAddress = "0x6b175474e89094c44da98b954eedeac495271d0f";
    let uniswapRouterAddress = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";

    before (async function () {
        [
            this.owner,
            this.user_1,
            this.user_2
        ] = await ethers.getSigners();

        this.dexRouter = new ethers.Contract(uniswapRouterAddress, uniswap_abi, this.owner);
        this.DAI = new ethers.Contract(daiAddress, erc20_abi, this.owner);
        this.collectionManager = await deploy("CollectionManager", "CollectionManager");
        this.serviceManager = await deploy("ServiceManager", "ServiceManager");
        this.deckMaster = await deploy(
            "DeckMaster", 
            "DeckMaster", 
            this.DAI.address, 
            this.collectionManager.address, 
            this.serviceManager.address,
            this.dexRouter.address
        );
    })

    it ("check deployed successfully and initialize contracts", async function () {
        console.log("deployed successfully!");
        await this.collectionManager.setDeckMaster(this.deckMaster.address);
        await this.serviceManager.setDeckMaster(this.deckMaster.address);
        console.log("initialized successfully!");
    })
})