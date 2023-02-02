const { expect } = require('chai');
const { ethers } = require('hardhat');
const { constants } = require('@openzeppelin/test-helpers');

const { uniswap_abi } = require('../external_abi/uniswap.abi.json');
const { erc20_abi } = require('../external_abi/erc20.abi.json');

const { deploy } = require('../scripts/utils');

describe ("Lending-Borrowing Protocol test", function () {
    let fevrAddress = "0x9fB83c0635De2E815fd1c21b3a292277540C2e8d";
    let daiAddress = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
    let usdtAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
    let usdcAddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
    let uniswapRouterAddress = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";

    before (async function () {
        [
            this.owner,
            this.user_1,
            this.user_2
        ] = await ethers.getSigners();

        this.dexRouter = new ethers.Contract(uniswapRouterAddress, uniswap_abi, this.owner);
        this.DAI = new ethers.Contract(daiAddress, erc20_abi, this.owner);
        this.Fevr = new ethers.Contract(fevrAddress, erc20_abi, this.owner);
        this.USDT = new ethers.Contract(usdtAddress, erc20_abi, this.owner);
        this.USDC = new ethers.Contract(usdcAddress, erc20_abi, this.owner);

        this.collectionManager = await deploy("CollectionManager", "CollectionManager");
        this.serviceManager = await deploy("ServiceManager", "ServiceManager");
        this.deckMaster = await deploy(
            "DeckMaster", 
            "DeckMaster", 
            this.Fevr.address, 
            this.collectionManager.address, 
            this.serviceManager.address,
            this.dexRouter.address
        );
        this.bundleNFT = await deploy("MockBundles", "MockBundles");
        this.collectionId = await deploy("MockCollectionId", "MockCollectionId");
    })

    it ("check deployed successfully and initialize contracts", async function () {
        console.log("deployed successfully!");
        await this.collectionManager.setDeckMaster(this.deckMaster.address);
        await this.serviceManager.setDeckMaster(this.deckMaster.address);
        console.log("initialized successfully!");
    })

    describe ("Set acceptable ERC20 token", function () {
        it ("get acceptable ERC20 token addresses", async function () {
            let allowedTokens = await this.deckMaster.getAllowedTokens();
            expect (allowedTokens.length).to.be.equal(0);
        })

        it ("add acceptable ERC20 tokens", async function () {
            await expect (
                this.deckMaster.connect(this.user_1).setAcceptableERC20(this.DAI.address, true)
            ).to.be.revertedWith("Ownable: caller is not the owner");

            await expect (
                this.deckMaster.setAcceptableERC20(constants.ZERO_ADDRESS, true)
            ).to.be.revertedWith("zero token address");

            await expect (
                this.deckMaster.setAcceptableERC20(this.DAI.address, true)
            ).to.be.emit(this.deckMaster, "AcceptableERC20Set")
            .withArgs(this.DAI.address, true);

            let allowedTokens = await this.deckMaster.getAllowedTokens();
            expect (allowedTokens.length).to.be.equal(1);
            expect (allowedTokens[0]).to.be.equal(this.DAI.address);
        })

        it ("remove acceptable ERC20 tokens", async function () {
            await expect (
                this.deckMaster.setAcceptableERC20(this.DAI.address, false)
            ).to.be.emit(this.deckMaster, "AcceptableERC20Set")
            .withArgs(this.DAI.address, false);

            let allowedTokens = await this.deckMaster.getAllowedTokens();
            expect (allowedTokens.length).to.be.equal(0);

            await this.deckMaster.setAcceptableERC20(this.DAI.address, true);
            await this.deckMaster.setAcceptableERC20(this.USDT.address, true);
            await this.deckMaster.setAcceptableERC20(this.Fevr.address, true);

            allowedTokens = await this.deckMaster.getAllowedTokens();
            expect (allowedTokens.length).to.be.equal(3);

            expect (allowedTokens[0]).to.be.equal(this.DAI.address);
            expect (allowedTokens[1]).to.be.equal(this.USDT.address);
            expect (allowedTokens[2]).to.be.equal(this.Fevr.address);
        })

        it ("reverts if already add/remove ERC20 tokens", async function () {
            await expect (
                this.deckMaster.setAcceptableERC20(this.DAI.address, true)
            ).to.be.revertedWith("Already set");
        })
    })

    describe ("Set acceptable collections", function () {
        it ("get acceptable collections", async function () {
            let allowedCollections = await this.deckMaster.getAllowedCollections();
            expect (allowedCollections.length).to.be.equal(0);
        })

        it ("add acceptable collections", async function () {
            await expect (
                this.deckMaster.connect(this.user_1).setAcceptableCollections([this.collectionId.address], true)
            ).to.be.revertedWith("Ownable: caller is not the owner");
            await expect (
                this.deckMaster.setAcceptableCollections([this.collectionId.address], true)
            ).to.be.emit(this.deckMaster, "AcceptableCollectionsSet");
            let allowedCollections = await this.deckMaster.getAllowedCollections();
            expect (allowedCollections.length).to.be.equal(1);
            expect (allowedCollections[0]).to.be.equal(this.collectionId.address);
        })

        it ("remove acceptable collections", async function () {
            await this.deckMaster.setAcceptableCollections([this.collectionId.address], false);
            allowedCollections = await this.deckMaster.getAllowedCollections();
            expect (allowedCollections.length).to.be.equal(0);
        })

        it ("reverts if already add/remove ERC20 tokens", async function () {
            await expect (
                this.deckMaster.setAcceptableCollections([this.collectionId.address], false)
            ).to.be.revertedWith("Already set");

            await this.deckMaster.setAcceptableCollections([this.collectionId.address], true);

            await expect (
                this.deckMaster.setAcceptableCollections([this.collectionId.address], true)
            ).to.be.revertedWith("Already set");
        })
    })

    describe ("Set acceptable bundle", function () {
        it ("get acceptable bundle addresses", async function () {
            let allowedBundles = await this.deckMaster.getAllowedBundles();
            expect (allowedBundles.length).to.be.equal(0);
        })
    
        it ("add acceptable bundles", async function () {
            await expect (
                this.deckMaster.connect(this.user_1).setAcceptableBundle(this.bundleNFT.address, true)
            ).to.be.revertedWith("Ownable: caller is not the owner");
    
            await expect (
                this.deckMaster.setAcceptableBundle(constants.ZERO_ADDRESS, true)
            ).to.be.revertedWith("zero address");
    
            await expect (
                this.deckMaster.setAcceptableBundle(this.bundleNFT.address, true)
            ).to.be.emit(this.deckMaster, "AcceptableBundleSet")
            .withArgs(this.bundleNFT.address, true);
    
            let allowedBundles = await this.deckMaster.getAllowedBundles();
            expect (allowedBundles.length).to.be.equal(1);
            expect (allowedBundles[0]).to.be.equal(this.bundleNFT.address);
        })
    
        it ("remove acceptable bundles", async function () {
            await expect (
                this.deckMaster.setAcceptableBundle(this.bundleNFT.address, false)
            ).to.be.emit(this.deckMaster, "AcceptableBundleSet")
            .withArgs(this.bundleNFT.address, false);
    
            let allowedBundles = await this.deckMaster.getAllowedBundles();
            expect (allowedBundles.length).to.be.equal(0);
    
            await this.deckMaster.setAcceptableBundle(this.bundleNFT.address, true);
    
            allowedBundles = await this.deckMaster.getAllowedBundles();
            expect (allowedBundles.length).to.be.equal(1);
            expect (allowedBundles[0]).to.be.equal(this.bundleNFT.address);
        })
    
        it ("reverts if already add/remove bundles", async function () {
            await expect (
                this.deckMaster.setAcceptableBundle(this.bundleNFT.address, true)
            ).to.be.revertedWith("Already set");
        })
    })

    describe ("set required collection amount for a bundle", function () {
        it ("reverts if caller is not the owner", async function () {
            await expect (
                this.deckMaster.connect(this.user_1).setCollectionAmountForBundle(50)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        })

        it ("reverts if amount is zero", async function () {
            await expect (
                this.deckMaster.setCollectionAmountForBundle(0)
            ).to.be.revertedWith("invalid amount");
        })

        it ("set required collection amount as 50", async function () {
            await expect (
                this.deckMaster.setCollectionAmountForBundle(50)
            ).to.be.emit(this.deckMaster, "CollectionAmountForBundleSet")
            .withArgs(50);
        })
    })
})