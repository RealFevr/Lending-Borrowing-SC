const { expect } = require('chai');
const { ethers } = require('hardhat');
const { constants } = require('@openzeppelin/test-helpers');

const { uniswap_abi } = require('../external_abi/uniswap.abi.json');
const { erc20_abi } = require('../external_abi/erc20.abi.json');

const { deploy, bigNum, smallNum, bigNum_6, getCurrentTimestamp, smallNum_6, spendTime, day } = require('../scripts/utils');

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
            this.user_2,
            this.user_3
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
        this.collectionId_1 = await deploy("MockCollectionId", "MockCollectionId");
    })

    it ("check deployed successfully and initialize contracts", async function () {
        console.log("deployed successfully!");
        await this.collectionManager.setDeckMaster(this.deckMaster.address);
        await this.serviceManager.setDeckMaster(this.deckMaster.address);
        console.log("initialized successfully!");
    })

    it ("swap ETH to USDT, DAI, FEVR", async function () {
        let WETH = await this.dexRouter.WETH();
        await this.dexRouter.swapExactETHForTokens(
            0,
            [WETH, this.USDT.address],
            this.owner.address,
            BigInt(await getCurrentTimestamp()) + BigInt(100),
            {value: bigNum(100)}
        );

        await this.dexRouter.swapExactETHForTokens(
            0,
            [WETH, this.DAI.address],
            this.owner.address,
            BigInt(await getCurrentTimestamp()) + BigInt(100),
            {value: bigNum(100)}
        );

        await this.dexRouter.swapExactETHForTokens(
            0,
            [WETH, this.Fevr.address],
            this.owner.address,
            BigInt(await getCurrentTimestamp()) + BigInt(100),
            {value: bigNum(100)}
        );
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

    describe ("set service and linke it to collection", function () {
        describe ("set service fee", function () {
            it ("reverts if caller is not the owner", async function () {
                await expect (
                    this.deckMaster.connect(this.user_1).setServiceFee(
                        constants.ZERO_ADDRESS,
                        10,
                        false,
                        "Low fee",
                        20
                    )
                ).to.be.revertedWith("Ownable: caller is not the owner");
            })
            it ("reverts if payment token is zero address", async function () {
                await expect (
                    this.deckMaster.setServiceFee(
                        constants.ZERO_ADDRESS,
                        10,
                        false,
                        "Low fee",
                        20
                    )
                ).to.be.revertedWith("not acceptable payment token address");
            })

            it ("set service fee", async function () {
                let feeAmount = bigNum(10);
                await expect (
                    this.deckMaster.setServiceFee(
                        this.DAI.address,
                        BigInt(feeAmount),
                        true,
                        "Medium Fee",
                        10  // 10%
                    )
                ).to.be.emit(this.deckMaster, "ServiceFeeSet")
                .withArgs(
                    this.DAI.address,
                    BigInt(feeAmount),
                    true,
                    "Medium Fee",
                    10
                );

                await this.deckMaster.setServiceFee(
                    this.Fevr.address,
                    bigNum(300),
                    true,
                    "Low Fee",
                    30  // 30%
                );

                let serviceFee = await this.deckMaster.getServiceFeeInfo(1);
                expect (serviceFee.paymentToken).to.be.equal(this.DAI.address);
                expect (smallNum(serviceFee.feeAmount)).to.be.equal(smallNum(feeAmount));
                expect (serviceFee.active).to.be.equal(true);
                expect (Number(serviceFee.burnPercent)).to.be.equal(10);

                serviceFee = await this.deckMaster.getServiceFeeInfo(2);
                expect (serviceFee.paymentToken).to.be.equal(this.Fevr.address);
                expect (smallNum(serviceFee.feeAmount)).to.be.equal(300);
                expect (serviceFee.active).to.be.equal(true);
                expect (Number(serviceFee.burnPercent)).to.be.equal(30);
            })
        })

        describe ("Link service fee to collections", function () {
            it ("reverts if caller is not the owner", async function () {
                await expect (
                    this.deckMaster.connect(this.user_1).linkServiceFee(1, this.collectionId.address)
                ).to.be.revertedWith("Ownable: caller is not the owner");
            })

            it ("reverts if serviceFeeId is not valid", async function () {
                let lastServiceFeeId = await this.deckMaster.serviceFeeId();
                await expect (
                    this.deckMaster.linkServiceFee(lastServiceFeeId + 3, this.collectionId.address)
                ).to.be.revertedWith("invalid serviceFeeId");
            })

            it ("reverts if collection address is not allowlisted", async function () {
                await expect (
                    this.deckMaster.linkServiceFee(1, this.collectionId_1.address)
                ).to.be.revertedWith("not acceptable collection address");
            })

            it ("link serviceFee to collection", async function () {
                await expect (
                    this.deckMaster.linkServiceFee(1, this.collectionId.address)
                ).to.be.emit(this.deckMaster, "ServiceFeeLinked")
                .withArgs(1, this.collectionId.address);
            })

            it ("reverts if serviceFee already linked", async function () {
                await expect (
                    this.deckMaster.linkServiceFee(1, this.collectionId.address)
                ).to.be.revertedWith("already linked to a fee");
            })

            it ("link serviceFee to bundle", async function () {
                await expect (
                    this.deckMaster.linkServiceFee(2, this.bundleNFT.address)
                ).to.be.emit(this.deckMaster, "ServiceFeeLinked")
                .withArgs(2, this.bundleNFT.address);
            })
        })
    })

    describe ("deposit collections and bundles", function () {
        describe ("deposit collections or bundles without setting deposit flag", function () {
            describe ("deposit collections without setting deposit flag", function () {
                it ("mint serverl collections to user_1", async function () {
                    await this.collectionId.mint(this.user_1.address, 5);
                })
    
                it ("reverts if deposit collection without setting deposit flag", async function () {
                    await this.collectionId.connect(this.user_1).setApprovalForAll(this.deckMaster.address, true);
                    await expect (
                        this.deckMaster.depositCollections(
                            this.collectionId.address,
                            [1, 2, 3, 4, 5]
                        )
                    ).to.be.revertedWith("exceeds to max deposit limit");
                })
            })

            describe ("deposit bundles without setting deposit flag", function () {
                it ("mint bundleNFT to user_1", async function () {
                    await this.collectionId.connect(this.user_1).setApprovalForAll(this.bundleNFT.address, true);
                    await this.bundleNFT.connect(this.user_1).depositNFTs(
                        [
                            this.collectionId.address, 
                            this.collectionId.address, 
                            this.collectionId.address, 
                            this.collectionId.address, 
                            this.collectionId.address
                        ],
                        [1, 2, 3, 4, 5],
                        "Bundle with 5 collections"
                    );
                })
    
                it ("reverts if deposit bundle without setting deposit flag", async function () {
                    await this.bundleNFT.connect(this.user_1).setApprovalForAll(this.deckMaster.address, true);
                    await expect (
                        this.deckMaster.connect(this.user_1).depositBundle(this.bundleNFT.address, 1)
                    ).to.be.revertedWith("exceeds to max deposit limit");
                })
            })
        })

        describe ("deposit collections", function () {
            it ("set deposit flag", async function () {
                await expect (
                    this.deckMaster.setDepositFlag(
                        this.collectionId.address,
                        100
                    )
                ).to.be.emit(this.deckMaster, "DepositFlagSet")
                .withArgs(this.collectionId.address, 100);
            })

            describe ("deposit collections after set deposit flag and check deckLp", async function () {
                it ("reverts if tokenIds length is zero", async function () {
                    await expect (
                        this.deckMaster.connect(this.user_1).depositCollections(
                            this.collectionId.address,
                            []
                        )
                    ).to.be.revertedWith("dismatched length");
                })

                it ("reverts if collection is not allowlisted", async function () {
                    await expect (
                        this.deckMaster.connect(this.user_1).depositCollections(
                            this.collectionId_1.address,
                            [1, 2, 3]
                        )
                    ).to.be.revertedWith("Not acceptable collection address");
                })

                it ("reverts if caller is not the collection owner", async function () {
                    await expect (
                        this.deckMaster.connect(this.user_2).depositCollections(
                            this.collectionId.address,
                            [1, 2, 3]
                        )
                    ).to.be.revertedWith("not Collection owner");
                })

                it ("deposit collections and check deckLp", async function () {
                    /// mint collectionId to user_1
                    await this.collectionId.mint(this.user_1.address, 7);

                    /// deposit collections
                    await this.collectionId.connect(this.user_1).setApprovalForAll(this.deckMaster.address, true);
                    await expect (
                        this.deckMaster.connect(this.user_1).depositCollections(
                            this.collectionId.address,
                            [6, 7, 8, 9, 10, 11, 12]
                        )
                    ).to.be.emit(this.deckMaster, "CollectionsDeposited")
                    .withArgs(
                        this.collectionId.address,
                        [6, 7, 8, 9, 10, 11, 12],
                        1
                    );

                    /// check deckLp balance and deckLp information
                    expect (await this.deckMaster.balanceOf(this.user_1.address)).to.be.equal(1);
                    await expect (
                        this.deckMaster.getDeckLpInfo(1000)
                    ).to.be.revertedWith("not exist deckLp id");
                    let deckLpInfo = await this.deckMaster.getDeckLpInfo(1);
                    expect (deckLpInfo.collectionAddress).to.be.equal(this.collectionId.address);
                    expect (deckLpInfo.tokenIds.length).to.be.equal(7);
                    expect (await this.deckMaster.getAllDeckCount()).to.be.equal(1);
                })
            })
        })
        
        describe ("deposit bundle", function () {
            it ("set deposit flag", async function () {
                await expect (
                    this.deckMaster.setDepositFlag(
                        this.bundleNFT.address,
                        10
                    )
                ).to.be.emit(this.deckMaster, "DepositFlagSet")
                .withArgs(this.bundleNFT.address, 10);
            })

            it ("reverts if caller is not the bundle NFT owner", async function () {
                await expect (
                    this.deckMaster.depositBundle(this.bundleNFT.address, 1)
                ).to.be.revertedWith("not Collection owner");
            })

            it ("reverts if bundle NFT is not allowlisted", async function () {
                await this.collectionId_1.mint(this.user_1.address, 1);
                await expect (
                    this.deckMaster.connect(this.user_1).depositBundle(this.collectionId_1.address, 1)
                ).to.be.revertedWith("Not acceptable bundle address");
            })
            
            it ("reverts if bundle doesn't have certain collection amount", async function () {
                await this.bundleNFT.connect(this.user_1).setApprovalForAll(this.deckMaster.address, true);
                await expect (
                    this.deckMaster.connect(this.user_1).depositBundle(this.bundleNFT.address, 1)
                ).to.be.revertedWith("Bundle should have certain collections");
            })

            it ("deposit bundle with certain collection amount and check deckLp", async function () {
                /// mint 50 collectionIds to user_1
                await this.collectionId.mint(this.user_1.address, 50);
                let lastTokenId = 13;
                let tokenIds = [];
                let tokenAddrs = [];
                for (let i = lastTokenId; i < lastTokenId + 50; i ++) {
                    tokenIds.push(i);
                    tokenAddrs.push(this.collectionId.address);
                }

                await this.collectionId.connect(this.user_1).setApprovalForAll(this.bundleNFT.address, true);
                await this.bundleNFT.connect(this.user_1).depositNFTs(tokenAddrs, tokenIds, "First Bundle with 50 collections");

                // deposit bundle and check deckLp
                await this.bundleNFT.connect(this.user_1).setApprovalForAll(this.deckMaster.address, true);
                await expect (
                    this.deckMaster.connect(this.user_1).depositBundle(this.bundleNFT.address, 2)
                ).to.be.emit(this.deckMaster, "BundleDeposited")
                .withArgs(this.bundleNFT.address, 2, 2);

                let deckLpInfo = await this.deckMaster.getDeckLpInfo(2);
                expect (deckLpInfo.collectionAddress).to.be.equal(this.bundleNFT.address);
                expect (deckLpInfo.tokenIds.length).to.be.equal(1);
                expect (await this.deckMaster.getAllDeckCount()).to.be.equal(2);
                expect (deckLpInfo.tokenIds[0]).to.be.equal(2);
            })
        })        
    })  

    describe ("withdraw collections and bundles", function () {
        describe ("withdraw collections", function () {
            it ("reverts if caller is not the deckLp owner", async function () {
                await expect (
                    this.deckMaster.connect(this.user_2).withdrawCollections(1)
                ).to.be.revertedWith("not deckLp owner");
            })

            it ("withdraw collections with deckLp and check deckLp is burn", async function () {
                let beforeBal = await this.collectionId.balanceOf(this.user_1.address);
                await expect (
                    this.deckMaster.connect(this.user_1).withdrawCollections(1)
                ).to.be.emit(this.deckMaster, "Withdraw")
                .withArgs(this.user_1.address, 1);
                let afterBal = await this.collectionId.balanceOf(this.user_1.address);

                expect (await this.deckMaster.getAllDeckCount()).to.be.equal(1);
                expect (await this.deckMaster.balanceOf(this.user_1.address)).to.be.equal(1);
                expect (afterBal - beforeBal).to.be.equal(7);
            })
        })

        describe ("withdraw bundle", function () {
            it ("withdraw bundle with deckLp and check deckLp is burn", async function () {
                let beforeBal = await this.bundleNFT.balanceOf(this.user_1.address);
                await expect (
                    this.deckMaster.connect(this.user_1).withdrawCollections(2)
                ).to.be.emit(this.deckMaster, "Withdraw")
                .withArgs(this.user_1.address, 2);
                let afterBal = await this.bundleNFT.balanceOf(this.user_1.address);

                expect (await this.deckMaster.getAllDeckCount()).to.be.equal(0);
                expect (await this.deckMaster.balanceOf(this.user_1.address)).to.be.equal(0);
                expect (afterBal - beforeBal).to.be.equal(1);
            })
        })
    })

    describe ("lend and borrow collections", function () {
        describe ("deposit collections and bundles for lending", function () {
            it ("deposit collections", async function () {
                await this.collectionId.connect(this.user_1).setApprovalForAll(this.deckMaster.address, true);
                await expect (
                    this.deckMaster.connect(this.user_1).depositCollections(
                        this.collectionId.address,
                        [6, 7, 8, 9, 10, 11, 12]
                    )
                ).to.be.emit(this.deckMaster, "CollectionsDeposited")
                .withArgs(
                    this.collectionId.address,
                    [6, 7, 8, 9, 10, 11, 12],
                    3
                );
                expect (await this.deckMaster.getAllDeckCount()).to.be.equal(1);
            })

            it ("deposit bundle", async function () {
                await this.bundleNFT.connect(this.user_1).setApprovalForAll(this.deckMaster.address, true);
                await expect (
                    this.deckMaster.connect(this.user_1).depositBundle(this.bundleNFT.address, 2)
                ).to.be.emit(this.deckMaster, "BundleDeposited")
                .withArgs(this.bundleNFT.address, 2, 4);
                expect (await this.deckMaster.getAllDeckCount()).to.be.equal(2);
            })
        })

        describe ("list lend with deckLp", function () {
            it ("reverts if lending duration is zero", async function () {
                await expect (
                    this.deckMaster.connect(this.user_1).lend(
                        this.USDT.address,
                        1,
                        bigNum_6(100),
                        bigNum_6(50),
                        0,
                        true,
                        {
                            lenderRate: 300,
                            borrowerRate: 500,
                            burnRate: 200 
                        }
                    )
                ).to.be.revertedWith("invalid lend duration");
            })
            it ("reverts if caller is not the deckLp owner", async function () {
                await expect (
                    this.deckMaster.connect(this.user_2).lend(
                        this.USDT.address,
                        3,
                        bigNum_6(100),
                        bigNum_6(50),
                        10,
                        true,
                        {
                            lenderRate: 300,
                            borrowerRate: 500,
                            burnRate: 200 
                        }
                    )
                ).to.be.revertedWith("not deckLp owner");
            })

            it ("reverts if try to lend with invalid prepay information", async function () {
                await expect (
                    this.deckMaster.connect(this.user_1).lend(
                        this.USDT.address,
                        3,
                        bigNum_6(100),
                        bigNum_6(50),
                        10,
                        false,
                        {
                            lenderRate: 300,
                            borrowerRate: 500,
                            burnRate: 200 
                        }
                    )
                ).to.be.revertedWith("invalid prepay amount");
            })

            it ("reverts if winning distribution is over 100%", async function () {
                await expect (
                    this.deckMaster.connect(this.user_1).lend(
                        this.USDT.address,
                        3,
                        bigNum_6(100),
                        bigNum_6(50),
                        10,
                        true,
                        {
                            lenderRate: 700,
                            borrowerRate: 500,
                            burnRate: 200 
                        }
                    )
                ).to.be.revertedWith("invalid winning distribution");
            })

            it ("list lend with deckLpId and check lend infos", async function () {
                await expect (
                    this.deckMaster.connect(this.user_1).lend(
                        this.USDT.address,
                        3,
                        bigNum_6(100),
                        bigNum_6(50),
                        10,
                        true,
                        {
                            lenderRate: 300,
                            borrowerRate: 500,
                            burnRate: 200 
                        }
                    )
                ).to.be.emit(this.deckMaster, "Lend")
                .withArgs(
                    this.user_1.address,
                    3
                );

                /// check lend infos
                let lendInfo = await this.serviceManager.getLendInfo(3);
                expect (lendInfo.lender).to.be.equal(this.user_1.address);
                expect (lendInfo.borrower).to.be.equal(constants.ZERO_ADDRESS);
                expect (lendInfo.paymentToken).to.be.equal(this.USDT.address);
                expect (smallNum_6(lendInfo.dailyInterest)).to.be.equal(100);
            })
        })

        describe ("borrow", function () {
            it ("reverts if try to borrow not exist deckLp", async function () {
                await expect (
                    this.deckMaster.borrow(1000)
                ).to.be.revertedWith("not exists deckLp id");
            })

            it ("reverts if caller is deckLp owner", async function () {
                await expect (
                    this.deckMaster.connect(this.user_1).borrow(3)
                ).to.be.revertedWith("caller is deckLp owner");
            })

            it ("reverts if not enough balance for service fee", async function () {
                await expect (
                    this.deckMaster.connect(this.user_2).borrow(4)
                ).to.be.revertedWith("not enough balance for serviceFee");
            })

            it ("reverts if not enough balance for prepay", async function () {
                await this.DAI.transfer(this.user_2.address, bigNum(20));
                await this.DAI.connect(this.user_2).approve(this.deckMaster.address, bigNum(10));
                await expect (
                    this.deckMaster.connect(this.user_2).borrow(3)
                ).to.be.revertedWith("not enough balance for prepay");
            })

            it ("reverts if not enough balance for interest", async function () {
                let prepay = bigNum_6(50);
                await this.USDT.transfer(this.user_2.address, BigInt(prepay));
                await this.USDT.connect(this.user_2).approve(this.deckMaster.address, BigInt(prepay));
                await expect (
                    this.deckMaster.connect(this.user_2).borrow(3)
                ).to.be.revertedWith("not enough balance for interest");
            })

            describe ("buyback", function () {
                it ("set buyback fee", async function () {
                    await this.deckMaster.setBuybackFee(
                        this.DAI.address,
                        100  // 10%
                    );

                    await this.deckMaster.buybackFeeTake(
                        this.DAI.address,
                        true
                    );
                })

                it ("brrow without buyback fee and check receipt deckLp, serviceFee and offerLend", async function () {
                    let serviceFeeAmount = bigNum(10);
                    await this.DAI.connect(this.user_2).approve(this.deckMaster.address, BigInt(serviceFeeAmount));

                    let prepay = bigNum_6(50);
                    let interests = bigNum_6(1000);
                    await this.USDT.transfer(this.user_2.address, BigInt(interests));
                    let totalRequireAmount = BigInt(prepay) + BigInt(interests);
                    await this.USDT.connect(this.user_2).approve(this.deckMaster.address, 0);
                    await this.USDT.connect(this.user_2).approve(this.deckMaster.address, BigInt(totalRequireAmount));
                    let beforeBal = await this.Fevr.balanceOf(this.deckMaster.address);
                    await expect (
                        this.deckMaster.connect(this.user_2).borrow(3)
                    ).to.be.emit(this.deckMaster, "Borrow")
                    .withArgs(this.user_2.address, 5);
                    let afterBal = await this.Fevr.balanceOf(this.deckMaster.address);

                    // check buyback
                    let burnRate = 10;
                    let burnAmount = BigInt(serviceFeeAmount) * BigInt(burnRate) / BigInt(1000);
                    let buybackAmount = BigInt(serviceFeeAmount) - BigInt(burnAmount);

                    let WETH = await this.dexRouter.WETH();
                    let amounts = await this.dexRouter.getAmountsOut(BigInt(buybackAmount), [this.DAI.address, WETH, this.Fevr.address]);
                    let expectFevrAmount = amounts[2];
                    let buybackFeeAmount = BigInt(expectFevrAmount) * BigInt(100) / BigInt(1000);

                    expect (smallNum(afterBal) - smallNum(beforeBal)).to.be.closeTo(smallNum(buybackFeeAmount), 0.1);
                    expect (smallNum_6(await this.deckMaster.getLockedERC20(this.USDT.address))).to.be.equal(1000);

                    /// check receipt deckLp info
                    expect (await this.deckMaster.balanceOf(this.user_2.address)).to.be.equal(1);
                    let [
                        lender, 
                        borrower, 
                        , , , , 
                    ] = await this.deckMaster.getReceiptDeckLpInfo(5);
                    expect (lender).to.be.equal(this.user_1.address);
                    expect (borrower).to.be.equal(this.user_2.address);
                })
            })
        })

        describe ("winning distribution", function () {
            it ("reverts if caller is not the owner", async function () {
                await expect (
                    this.deckMaster.connect(this.user_1).winningCalculation(
                        3, 
                        bigNum(100),
                        [1, 2, 3]
                    )
                ).to.be.revertedWith("Ownable: caller is not the owner");
            })

            it ("reverts if deckLp is receipt deckLp", async function () {
                await expect (
                    this.deckMaster.winningCalculation(
                        5, 
                        bigNum(100),
                        [1, 2, 3]
                    )
                ).to.be.revertedWith("this deckLp is receipt deckLp");
            })

            it ("set winningCalculation and check burn token and claimable token amount", async function () {
                let totalWinnings = bigNum(10000);
                await this.Fevr.transfer(this.deckMaster.address, BigInt(totalWinnings));
                let beforeBal = await this.Fevr.balanceOf(this.deckMaster.address);
                await expect (
                    this.deckMaster.winningCalculation(
                        3, 
                        BigInt(totalWinnings),
                        [1, 2, 3]
                    )
                ).to.be.emit(this.deckMaster, "WinningRewardsSet")
                .withArgs(3, [1, 2, 3], BigInt(totalWinnings));
                let afterBal = await this.Fevr.balanceOf(this.deckMaster.address);

                let lenderRate = 300;
                let borrowerRate = 500;
                let burnRate = 200 ;

                let lenderAmount = BigInt(totalWinnings) * BigInt(lenderRate) / BigInt(1000);
                let borrowerAmount = BigInt(totalWinnings) * BigInt(borrowerRate) / BigInt(1000);
                let burnAmount = BigInt(totalWinnings) * BigInt(burnRate) / BigInt(1000);

                expect (smallNum(await this.deckMaster.claimableAmount(this.user_1.address, 3))).to.be.closeTo(smallNum(lenderAmount), 0.1);
                expect (smallNum(await this.deckMaster.claimableAmount(this.user_2.address, 3))).to.be.closeTo(smallNum(borrowerAmount), 0.1);
                expect (smallNum(beforeBal) - smallNum(afterBal)).to.be.closeTo(smallNum(burnAmount), 0.1);
            })

            describe ("claim winning rewards", function () {
                it ("reverts if deckLpId is receipt deckLp", async function () {
                    await expect (
                        this.deckMaster.claimWinnings(5)
                    ).to.be.revertedWith("this deckLp is receipt deckLp");
                })

                it ("reverts if caller is not the owner or lender", async function () {
                    await expect (
                        this.deckMaster.connect(this.user_3).claimWinnings(3)
                    ).to.be.revertedWith("caller is not lender or borrower");
                })

                it ("claim winning rewards and check balance", async function () {
                    let expectAmount = await this.deckMaster.claimableAmount(this.user_1.address, 3);
                    let beforeBal = await this.Fevr.balanceOf(this.user_1.address);
                    await expect (
                        this.deckMaster.connect(this.user_1).claimWinnings(3)
                    ).to.be.emit(this.deckMaster, "WinningRewardsClaimed")
                    .withArgs(this.user_1.address, 3);
                    let afterBal = await this.Fevr.balanceOf(this.user_1.address);
                    expect (smallNum(afterBal) - smallNum(beforeBal)).to.be.closeTo(smallNum(expectAmount), 0.1);
                })

                it ("reverts if no claimable rewards", async function () {
                    await expect (
                        this.deckMaster.connect(this.user_1).claimWinnings(3)
                    ).to.be.revertedWith("no claimable winning rewards");
                })
            })
        })

        describe ("claim interests", function () {
            it ("reverts if try to claim with receipt deckLp id", async function () {
                await expect (
                    this.deckMaster.claimInterest(5)
                ).to.be.revertedWith("this deckLp is receipt deckLp");
            })

            it ("reverts if deckLpId is not lent deckLpId", async function () {
                await expect (
                    this.deckMaster.claimInterest(4)
                ).to.be.revertedWith("this deck is not lent deckLp");
            })

            it ("reverts if caller is not the lender", async function () {
                await expect (
                    this.deckMaster.claimInterest(3)
                ).to.be.revertedWith("not lender");
            })

            it ("reverts if try to claim rewards before maturity", async function () {
                await expect (
                    this.deckMaster.connect(this.user_1).claimInterest(3)
                ).to.be.revertedWith("can not claim interest in lend duration");
            })

            it ("claim interests and check receipt deckLp is burn", async function () {
                /// spend time
                await spendTime(12 * day);
                let expectInterestAmount = await this.deckMaster.getLockedERC20(this.USDT.address);
                expect (await this.deckMaster.balanceOf(this.user_2.address)).to.be.equal(1);
                let beforeBal = await this.USDT.balanceOf(this.user_1.address);
                await expect (
                    this.deckMaster.connect(this.user_1).claimInterest(3)
                ).to.be.emit(this.deckMaster, "InterestClaimed")
                .withArgs(this.user_1.address, BigInt(expectInterestAmount));
                let afterBal = await this.USDT.balanceOf(this.user_1.address);
                expect (smallNum_6(afterBal) - smallNum_6(beforeBal)).to.be.closeTo(smallNum_6(expectInterestAmount), 0.001);
                expect (smallNum_6(await this.deckMaster.getLockedERC20(this.USDT.address))).to.be.equal(0);
                expect (await this.deckMaster.balanceOf(this.user_2.address)).to.be.equal(0);
            })
        })
    })
})