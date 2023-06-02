const { expect } = require("chai");
const { ethers } = require("hardhat");
const { constants } = require("@openzeppelin/test-helpers");

const { uniswap_abi } = require("../external_abi/uniswap.abi.json");
const { erc20_abi } = require("../external_abi/erc20.abi.json");

const {
    deploy,
    smallNum,
    getCurrentTimestamp,
    bigNum,
    spendTime,
    day,
} = require("../scripts/utils");

describe("Lending-Borrowing Protocol test", function () {
    let uniswapRouterAddress = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
    let fevrAddress = "0x9fB83c0635De2E815fd1c21b3a292277540C2e8d";
    let daiAddress = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
    let usdtAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
    let usdcAddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
    let DEADWallet = "0x000000000000000000000000000000000000dEaD";
    let borrowId;
    let WETH;

    before(async function () {
        [
            this.deployer,
            this.lender_1,
            this.lender_2,
            this.lender_3,
            this.borrower_1,
            this.borrower_2,
            this.borrower_3,
        ] = await ethers.getSigners();
        this.dexRouter = new ethers.Contract(
            uniswapRouterAddress,
            uniswap_abi,
            this.deployer
        );
        this.DAI = new ethers.Contract(daiAddress, erc20_abi, this.deployer);
        this.Fevr = new ethers.Contract(fevrAddress, erc20_abi, this.deployer);
        this.USDT = new ethers.Contract(usdtAddress, erc20_abi, this.deployer);
        this.USDC = new ethers.Contract(usdcAddress, erc20_abi, this.deployer);

        this.treasury = await deploy(
            "Treasury",
            "Treasury",
            this.Fevr.address,
            this.dexRouter.address
        );
        this.lendingMaster = await deploy(
            "LendingMaster",
            "LendingMaster",
            this.treasury.address
        );
        this.NLBundle_1 = await deploy("MockBundles", "MockBundles");
        this.NLBundle_2 = await deploy("MockBundles", "MockBundles");
        this.NLBundle_3 = await deploy("MockBundles", "MockBundles");
        this.collection_1 = await deploy(
            "MockCollectionId",
            "MockCollectionId"
        );
        this.collection_2 = await deploy(
            "MockCollectionId",
            "MockCollectionId"
        );
        this.collection_3 = await deploy(
            "MockCollectionId",
            "MockCollectionId"
        );
        WETH = await this.dexRouter.WETH();
    });

    it("check deployment and initialize Treasury contract", async function () {
        console.log("deployed successfully!");
        console.log("initializing treasury contract...");
        await expect(
            this.treasury
                .connect(this.lender_1)
                .setLendingMaster(this.lendingMaster.address)
        ).to.be.revertedWith("Ownable: caller is not the owner");
        await this.treasury.setLendingMaster(this.lendingMaster.address);
        console.log("initialized successfully!");
    });

    it("swap ETH to USDT, DAI and Fevr", async function () {
        let decimals = await this.USDT.decimals();
        console.log("USDT decimals", decimals);
        let beforeBal = await this.USDT.balanceOf(this.deployer.address);
        await this.dexRouter.swapExactETHForTokens(
            0,
            [WETH, this.USDT.address],
            this.deployer.address,
            BigInt(await getCurrentTimestamp()) + BigInt(100),
            { value: bigNum(100) }
        );
        let afterBal = await this.USDT.balanceOf(this.deployer.address);
        console.log(
            "received USDT amount: ",
            smallNum(BigInt(afterBal) - BigInt(beforeBal), decimals)
        );

        decimals = await this.DAI.decimals();
        beforeBal = await this.DAI.balanceOf(this.deployer.address);
        await this.dexRouter.swapExactETHForTokens(
            0,
            [WETH, this.DAI.address],
            this.deployer.address,
            BigInt(await getCurrentTimestamp()) + BigInt(100),
            { value: bigNum(100) }
        );
        afterBal = await this.DAI.balanceOf(this.deployer.address);
        console.log(
            "received DAI amount: ",
            smallNum(BigInt(afterBal) - BigInt(beforeBal), decimals)
        );

        decimals = await this.Fevr.decimals();
        beforeBal = await this.Fevr.balanceOf(this.deployer.address);
        await this.dexRouter.swapExactETHForTokens(
            0,
            [WETH, this.Fevr.address],
            this.deployer.address,
            BigInt(await getCurrentTimestamp()) + BigInt(100),
            { value: bigNum(100) }
        );
        afterBal = await this.Fevr.balanceOf(this.deployer.address);
        console.log(
            "received Fevr amount: ",
            smallNum(BigInt(afterBal) - BigInt(beforeBal), decimals)
        );
    });

    describe("setTreasury", function () {
        it("reverts if caller is not the owner", async function () {
            await expect(
                this.lendingMaster
                    .connect(this.lender_1)
                    .setTreasury(this.treasury.address)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("setTreasury and check", async function () {
            await this.lendingMaster.setTreasury(this.treasury.address);
        });
    });

    describe("setAcceptableERC20", function () {
        it("reverts if caller is not the owner", async function () {
            await expect(
                this.lendingMaster
                    .connect(this.lender_1)
                    .setAcceptableERC20([], true)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("reverts if array length is zero", async function () {
            await expect(
                this.lendingMaster.setAcceptableERC20([], true)
            ).to.be.revertedWith("invalid length array");
        });

        it("add acceptable tokens", async function () {
            let allowedTokens = await this.lendingMaster.getAllowedTokens();
            expect(allowedTokens.length).to.be.equal(0);
            await this.lendingMaster.setAcceptableERC20(
                [
                    constants.ZERO_ADDRESS,
                    this.USDT.address,
                    this.DAI.address,
                    this.Fevr.address,
                    this.USDC.address,
                ],
                true
            );
            allowedTokens = await this.lendingMaster.getAllowedTokens();
            expect(allowedTokens.length).to.be.equal(5);
        });

        it("reverts if already added", async function () {
            await expect(
                this.lendingMaster.setAcceptableERC20([this.USDT.address], true)
            ).to.be.revertedWith("already added");
        });

        it("remove token", async function () {
            let beforeAllowedTokens =
                await this.lendingMaster.getAllowedTokens();
            await this.lendingMaster.setAcceptableERC20(
                [this.USDC.address],
                false
            );
            let afterAllowedTokens =
                await this.lendingMaster.getAllowedTokens();
            expect(
                beforeAllowedTokens.length - afterAllowedTokens.length
            ).to.be.equal(1);
        });

        it("reverts if already removed", async function () {
            await expect(
                this.lendingMaster.setAcceptableERC20(
                    [this.USDC.address],
                    false
                )
            ).to.be.revertedWith("already removed");
        });
    });

    describe("setApprovedCollections", function () {
        it("reverts if caller is not the owner", async function () {
            await expect(
                this.lendingMaster
                    .connect(this.lender_1)
                    .setApprovedCollections([], true)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("reverts if array length is zero", async function () {
            await expect(
                this.lendingMaster.setApprovedCollections([], true)
            ).to.be.revertedWith("invalid length array");
        });

        it("add acceptable collections", async function () {
            let beforeCollections =
                await this.lendingMaster.getAllowedCollections();
            await this.lendingMaster.setApprovedCollections(
                [
                    this.collection_1.address,
                    this.collection_2.address,
                    this.collection_3.address,
                ],
                true
            );
            let afterCollections =
                await this.lendingMaster.getAllowedCollections();
            expect(
                afterCollections.length - beforeCollections.length
            ).to.be.equal(3);
        });

        it("reverts if already added", async function () {
            await expect(
                this.lendingMaster.setApprovedCollections(
                    [this.collection_2.address],
                    true
                )
            ).to.be.revertedWith("already added");
        });

        it("remove acceptable collection", async function () {
            let beforeCollections =
                await this.lendingMaster.getAllowedCollections();
            await this.lendingMaster.setApprovedCollections(
                [this.collection_3.address],
                false
            );
            let afterCollections =
                await this.lendingMaster.getAllowedCollections();
            expect(
                beforeCollections.length - afterCollections.length
            ).to.be.equal(1);
        });

        it("reverts if already removed", async function () {
            await expect(
                this.lendingMaster.setApprovedCollections(
                    [this.collection_3.address],
                    false
                )
            ).to.be.revertedWith("already removed");
        });
    });

    describe("setNLBundles", function () {
        it("reverts if caller is not the owner", async function () {
            await expect(
                this.lendingMaster.connect(this.lender_1).setNLBundles([], true)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("reverts if array length is zero", async function () {
            await expect(
                this.lendingMaster.setNLBundles([], true)
            ).to.be.revertedWith("invalid length array");
        });

        it("add acceptable NLBundles", async function () {
            let beforeNLBundles =
                await this.lendingMaster.getAllowedNLBundles();
            await this.lendingMaster.setNLBundles(
                [
                    this.NLBundle_1.address,
                    this.NLBundle_2.address,
                    this.NLBundle_3.address,
                ],
                true
            );
            let afterNLBundles = await this.lendingMaster.getAllowedNLBundles();
            expect(afterNLBundles.length - beforeNLBundles.length).to.be.equal(
                3
            );
        });

        it("reverts if already added", async function () {
            await expect(
                this.lendingMaster.setNLBundles([this.NLBundle_1.address], true)
            ).to.be.revertedWith("already added");
        });

        it("remove acceptable NLBundles", async function () {
            let beforeNLBundles =
                await this.lendingMaster.getAllowedNLBundles();
            await this.lendingMaster.setNLBundles(
                [this.NLBundle_3.address],
                false
            );
            let afterNLBundles = await this.lendingMaster.getAllowedNLBundles();
            expect(beforeNLBundles.length - afterNLBundles.length).to.be.equal(
                1
            );
        });

        it("reverts if already removed", async function () {
            await expect(
                this.lendingMaster.setNLBundles(
                    [this.NLBundle_3.address],
                    false
                )
            ).to.be.revertedWith("already removed");
        });
    });

    describe("set service fee and link it to collection", function () {
        describe("set service fee", function () {
            it("reverts if caller is not the owner", async function () {
                await expect(
                    this.lendingMaster.connect(this.lender_1).setServiceFee(
                        this.DAI.address,
                        bigNum(10, 18),
                        true,
                        "DAI fee setting",
                        100 // 10%
                    )
                ).to.be.revertedWith("Ownable: caller is not the owner");
            });

            it("reverts if payment token is not allowed", async function () {
                await expect(
                    this.lendingMaster.setServiceFee(
                        this.USDC.address,
                        bigNum(10, 6),
                        true,
                        "USDC fee setting",
                        100 // 10%
                    )
                ).to.be.revertedWith("token is not allowed");
            });

            it("reverts if burnPercent is over 100%", async function () {
                await expect(
                    this.lendingMaster.setServiceFee(
                        this.DAI.address,
                        bigNum(10, 18),
                        true,
                        "DAI fee setting",
                        10000
                    )
                ).to.be.revertedWith("invalid burn percent");
            });

            it("reverts if feeAmount is zero", async function () {
                await expect(
                    this.lendingMaster.setServiceFee(
                        this.DAI.address,
                        0,
                        true,
                        "DAI fee setting",
                        100 // 10%
                    )
                ).to.be.revertedWith("invalid feeAmount");
            });

            it("setServiceFee", async function () {
                await this.lendingMaster.setServiceFee(
                    constants.ZERO_ADDRESS,
                    bigNum(1, 17),
                    true,
                    "ETH fee setting",
                    100 // 10%
                );

                let serviceFeeInfo = await this.lendingMaster.serviceFees(1);
                expect(serviceFeeInfo.paymentToken).to.be.equal(
                    constants.ZERO_ADDRESS
                );
                expect(smallNum(serviceFeeInfo.feeAmount, 18)).to.be.equal(0.1);
                expect(await this.lendingMaster.serviceFeeId()).to.be.equal(2);
            });
        });

        describe("linkServiceFee", function () {
            it("reverts if caller is not the owner", async function () {
                await expect(
                    this.lendingMaster
                        .connect(this.lender_1)
                        .linkServiceFee(1, this.collection_1.address)
                ).to.be.revertedWith("Ownable: caller is not the owner");
            });

            it("reverts if serviceFeeId is invalid", async function () {
                await expect(
                    this.lendingMaster.linkServiceFee(
                        100,
                        this.collection_1.address
                    )
                ).to.be.revertedWith("invalid serviceFeeId");
            });

            it("reverts if collection is not acceptable", async function () {
                await expect(
                    this.lendingMaster.linkServiceFee(
                        1,
                        this.collection_3.address
                    )
                ).to.be.revertedWith("not acceptable collection address");
            });

            it("linkServiceFee", async function () {
                await this.lendingMaster.linkServiceFee(
                    1,
                    this.collection_1.address
                );
            });

            it("reverts if serviceFee is already linked", async function () {
                await expect(
                    this.lendingMaster.linkServiceFee(
                        1,
                        this.collection_1.address
                    )
                ).to.be.revertedWith("already linked to a fee");
            });
        });
    });

    describe("configAmountForBundle", function () {
        it("reverts if caller is not the owner", async function () {
            await expect(
                this.lendingMaster
                    .connect(this.lender_1)
                    .configAmountForBundle(1, 2)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("reverts minAmount and maxAmount are invalid", async function () {
            await expect(
                this.lendingMaster.configAmountForBundle(0, 20)
            ).to.be.revertedWith("invalid config amount");
        });

        it("configAmountForBundle", async function () {
            await this.lendingMaster.configAmountForBundle(2, 20);
        });
    });

    describe("setDepositFlag", function () {
        let depositLimit = { minAmount: 2, maxAmount: 20 };
        it("reverts if caller is not the owner", async function () {
            await expect(
                this.lendingMaster
                    .connect(this.lender_1)
                    .setDepositFlag(this.collection_1.address, depositLimit)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("reverts if collection is not approved", async function () {
            await expect(
                this.lendingMaster.setDepositFlag(
                    this.collection_3.address,
                    depositLimit
                )
            ).to.be.revertedWith("not acceptable collection address");
        });

        it("reverts if depositLimit is invalid", async function () {
            await expect(
                this.lendingMaster.setDepositFlag(this.collection_1.address, {
                    minAmount: 100,
                    maxAmount: 20,
                })
            ).to.be.revertedWith("invalid config amount");
        });

        it("setDepositFlag", async function () {
            await this.lendingMaster.setDepositFlag(
                this.collection_1.address,
                depositLimit
            );
            await this.lendingMaster.setDepositFlag(
                this.NLBundle_1.address,
                depositLimit
            );
        });
    });

    describe("set buybackFee settings", function () {
        describe("setBuybackFee", function () {
            it("reverts if caller is not the owner", async function () {
                await expect(
                    this.lendingMaster.connect(this.lender_1).setBuybackFee(
                        this.DAI.address,
                        200 // 20%
                    )
                ).to.be.revertedWith("Ownable: caller is not the owner");
            });

            it("reverts if token is not allowed", async function () {
                await expect(
                    this.lendingMaster.setBuybackFee(this.USDC.address, 20)
                ).to.be.revertedWith("token is not allowed");
            });

            it("reverts if buybackFee rate is zero", async function () {
                await expect(
                    this.lendingMaster.setBuybackFee(this.DAI.address, 0)
                ).to.be.revertedWith("invalid buybackFee rate");
            });

            it("setBuybackFee", async function () {
                await this.lendingMaster.setBuybackFee(this.DAI.address, 100);
                await this.lendingMaster.setBuybackFee(this.USDT.address, 150);
            });
        });

        describe("buybackFeeTake", function () {
            it("reverts if caller is not the owner", async function () {
                await expect(
                    this.lendingMaster
                        .connect(this.lender_1)
                        .buybackFeeTake(this.DAI.address, true)
                ).to.be.revertedWith("Ownable: caller is not the owner");
            });

            it("reverts if token is not allowed", async function () {
                await expect(
                    this.lendingMaster.buybackFeeTake(this.USDC.address, true)
                ).to.be.revertedWith("token is not allowed");
            });

            it("reverts if buybackFee rate is zero", async function () {
                await expect(
                    this.lendingMaster.buybackFeeTake(this.Fevr.address, true)
                ).to.be.revertedWith("buybackFee rate is not set");
            });

            it("buybackFeeTake", async function () {
                await this.lendingMaster.setBuybackFee(this.Fevr.address, 200);
                await this.lendingMaster.buybackFeeTake(
                    this.Fevr.address,
                    true
                );
                await this.lendingMaster.buybackFeeTake(this.DAI.address, true);
                await this.lendingMaster.buybackFeeTake(
                    this.USDT.address,
                    true
                );

                await this.lendingMaster.setBuybackFee(
                    constants.ZERO_ADDRESS,
                    200
                );
                await this.lendingMaster.buybackFeeTake(
                    constants.ZERO_ADDRESS,
                    true
                );
            });
        });
    });

    describe("deposit collection and NLBundle", function () {
        it("mint collections and NLBundles", async function () {
            await this.collection_1.mint(this.lender_1.address, 100);
            await this.collection_2.mint(this.lender_1.address, 100);
            await this.collection_2.mint(this.lender_2.address, 10);

            let depositIds = [];
            let depositAddr_1 = [];
            let depositAddr_2 = [];
            for (let i = 1; i <= 50; i++) {
                depositIds.push(i);
                depositAddr_1.push(this.collection_1.address);
                depositAddr_2.push(this.collection_2.address);
            }
            await this.collection_1
                .connect(this.lender_1)
                .setApprovalForAll(this.NLBundle_1.address, true);
            await this.collection_1
                .connect(this.lender_1)
                .setApprovalForAll(this.NLBundle_2.address, true);
            await this.collection_2
                .connect(this.lender_1)
                .setApprovalForAll(this.NLBundle_1.address, true);
            await this.collection_2
                .connect(this.lender_1)
                .setApprovalForAll(this.NLBundle_2.address, true);
            await this.NLBundle_1.connect(this.lender_1).depositNFTs(
                depositAddr_1,
                depositIds,
                "First NLBundle"
            );
            await this.NLBundle_2.connect(this.lender_1).depositNFTs(
                depositAddr_2,
                depositIds,
                "Second NLBundle"
            );

            let depositIds_1 = [];
            delete depositAddr_1;
            delete depositAddr_2;
            depositAddr_1 = [];
            depositAddr_2 = [];
            for (let i = 51; i <= 60; i++) {
                depositIds_1.push(i);
                depositAddr_1.push(this.collection_1.address);
                depositAddr_2.push(this.collection_2.address);
            }
            await this.NLBundle_1.connect(this.lender_1).depositNFTs(
                depositAddr_1,
                depositIds_1,
                "First NLBundle"
            );
            await this.NLBundle_2.connect(this.lender_1).depositNFTs(
                depositAddr_2,
                depositIds_1,
                "Second NLBundle"
            );
        });

        describe("deposit collection", function () {
            it("reverts if array length is zero", async function () {
                await expect(
                    this.lendingMaster
                        .connect(this.lender_1)
                        .depositCollection([], [], false)
                ).to.be.revertedWith("invalid length array");
            });

            it("reverts array length is mismatch", async function () {
                await expect(
                    this.lendingMaster.depositCollection(
                        [this.collection_1.address],
                        [],
                        false
                    )
                ).to.be.revertedWith("mismatch length array");
            });

            it("reverts if collection is not allowed", async function () {
                await expect(
                    this.lendingMaster.depositCollection(
                        [this.collection_3.address],
                        [1],
                        false
                    )
                ).to.be.revertedWith("not allowed collection");
            });

            it("reverts if collection owner is not caller", async function () {
                await expect(
                    this.lendingMaster
                        .connect(this.lender_2)
                        .depositCollection(
                            [this.collection_1.address],
                            [1],
                            false
                        )
                ).to.be.revertedWith("not collection owner");
            });

            // it("reverts deposit limit exceeds", async function () {
            //     let depositIds = [];
            //     let collectionAddr = [];
            //     for (let i = 61; i <= 100; i++) {
            //         depositIds.push(i);
            //         collectionAddr.push(this.collection_1.address);
            //     }

            //     await this.collection_1
            //         .connect(this.lender_1)
            //         .setApprovalForAll(this.lendingMaster.address, true);
            //     await expect(
            //         this.lendingMaster
            //             .connect(this.lender_1)
            //             .depositCollection(collectionAddr, depositIds, false)
            //     ).to.be.revertedWith("exceeds to max deposit limit");
            // });

            it("deposit collections", async function () {
                let depositIds = [];
                let collectionAddr = [];
                for (let i = 61; i <= 70; i++) {
                    depositIds.push(i);
                    collectionAddr.push(this.collection_1.address);
                }

                await this.collection_1
                    .connect(this.lender_1)
                    .setApprovalForAll(this.lendingMaster.address, true);

                let beforeBal = await this.collection_1.balanceOf(
                    this.lender_1.address
                );
                let beforeDeckId = await this.lendingMaster.depositId();
                let beforeDepositedIds =
                    await this.lendingMaster.getUserDepositedIds(
                        this.lender_1.address
                    );
                await this.lendingMaster
                    .connect(this.lender_1)
                    .depositCollection(collectionAddr, depositIds, false);
                let afterDeckId = await this.lendingMaster.depositId();
                let afterDepositedIds =
                    await this.lendingMaster.getUserDepositedIds(
                        this.lender_1.address
                    );
                let afterBal = await this.collection_1.balanceOf(
                    this.lender_1.address
                );
                expect(Number(afterDeckId) - Number(beforeDeckId)).to.be.equal(
                    10
                );
                expect(
                    afterDepositedIds.length - beforeDepositedIds.length
                ).to.be.equal(Number(afterDeckId) - Number(beforeDeckId));
                expect(Number(beforeBal) - Number(afterBal)).to.be.equal(10);

                await this.lendingMaster.setDepositFlag(
                    this.collection_2.address,
                    { minAmount: 2, maxAmount: 20 }
                );
                await this.collection_2
                    .connect(this.lender_2)
                    .setApprovalForAll(this.lendingMaster.address, true);
                await this.lendingMaster
                    .connect(this.lender_2)
                    .depositCollection(
                        [this.collection_2.address, this.collection_2.address],
                        [101, 102],
                        false
                    );
            });
        });

        describe("deposit NLBundle", function () {
            it("reverts if NLBundle is not approved", async function () {
                await expect(
                    this.lendingMaster
                        .connect(this.lender_1)
                        .depositNLBundle(this.NLBundle_3.address, 1)
                ).to.be.revertedWith("not allowed bundle");
            });

            it("reverts if NLBundle owner is not caller", async function () {
                await expect(
                    this.lendingMaster
                        .connect(this.lender_2)
                        .depositNLBundle(this.NLBundle_1.address, 1)
                ).to.be.revertedWith("not bundle owner");
            });

            it("reverts if bundle contains collection amount is over max amount", async function () {
                await expect(
                    this.lendingMaster
                        .connect(this.lender_1)
                        .depositNLBundle(this.NLBundle_1.address, 1)
                ).to.be.revertedWith("exceeds to depositLimitation");
            });

            it("deposit NLBundle", async function () {
                await this.NLBundle_1.connect(this.lender_1).setApprovalForAll(
                    this.lendingMaster.address,
                    true
                );
                let beforeBal = await this.NLBundle_1.balanceOf(
                    this.lender_1.address
                );
                await this.lendingMaster
                    .connect(this.lender_1)
                    .depositNLBundle(this.NLBundle_1.address, 2);
                let afterBal = await this.NLBundle_1.balanceOf(
                    this.lender_1.address
                );
                expect(Number(beforeBal) - Number(afterBal)).to.be.equal(1);
            });

            it("reverts if deposit limit exceeds", async function () {
                await expect(
                    this.lendingMaster
                        .connect(this.lender_1)
                        .depositNLBundle(this.NLBundle_2.address, 2)
                ).to.be.revertedWith("exceeds to depositLimitation");
            });
        });
    });

    describe("lend & borrow single collection and NLBundle", function () {
        describe("lend single collection and NLBundle", function () {
            describe("lend single deck", function () {
                let depositedIds;
                it("reverts if array length is zero", async function () {
                    await expect(
                        this.lendingMaster.connect(this.lender_1).lend([], [])
                    ).to.be.revertedWith("invalid length array");
                });

                it("revers if array length is mismatch", async function () {
                    depositedIds = await this.lendingMaster.getUserDepositedIds(
                        this.lender_1.address
                    );
                    await expect(
                        this.lendingMaster
                            .connect(this.lender_1)
                            .lend([depositedIds[0]], [])
                    ).to.be.revertedWith("mismatch length array");
                });

                it("reverts if caller is not deck owner", async function () {
                    await expect(
                        this.lendingMaster.connect(this.lender_2).lend(
                            [depositedIds[0]],
                            [
                                {
                                    paymentToken: this.DAI.address,
                                    prepayAmount: bigNum(30, 18),
                                    lendDuration: 7,
                                    winningRateForLender: 300,
                                    winningRateForBorrower: 200,
                                    gameFee: 0,
                                    prepay: true,
                                },
                            ]
                        )
                    ).to.be.revertedWith("not deck owner");
                });

                it("reverts if payment token is not allowed", async function () {
                    await expect(
                        this.lendingMaster.connect(this.lender_1).lend(
                            [depositedIds[0]],
                            [
                                {
                                    paymentToken: this.USDC.address,
                                    prepayAmount: bigNum(30, 18),
                                    lendDuration: 7,
                                    winningRateForLender: 300,
                                    winningRateForBorrower: 200,
                                    gameFee: 0,
                                    prepay: true,
                                },
                            ]
                        )
                    ).to.be.revertedWith("token is not allowed");
                });

                it("reverts if winningRate is invalid", async function () {
                    await expect(
                        this.lendingMaster.connect(this.lender_1).lend(
                            [depositedIds[0]],
                            [
                                {
                                    paymentToken: this.DAI.address,
                                    prepayAmount: bigNum(30, 18),
                                    lendDuration: 7,
                                    winningRateForLender: 800,
                                    winningRateForBorrower: 200,
                                    gameFee: 0,
                                    prepay: true,
                                },
                            ]
                        )
                    ).to.be.revertedWith("invalid winningRate");
                });

                it("reverts if lendDuration is zero", async function () {
                    await expect(
                        this.lendingMaster.connect(this.lender_1).lend(
                            [depositedIds[0]],
                            [
                                {
                                    paymentToken: this.DAI.address,
                                    prepayAmount: bigNum(30, 18),
                                    lendDuration: 0,
                                    winningRateForLender: 300,
                                    winningRateForBorrower: 200,
                                    gameFee: 0,
                                    prepay: true,
                                },
                            ]
                        )
                    ).to.be.revertedWith("invalid lendDuration");
                });

                it("reverts if prepay setting is incorrect", async function () {
                    await expect(
                        this.lendingMaster.connect(this.lender_1).lend(
                            [depositedIds[0]],
                            [
                                {
                                    paymentToken: this.DAI.address,
                                    prepayAmount: bigNum(30, 18),
                                    lendDuration: 7,
                                    winningRateForLender: 300,
                                    winningRateForBorrower: 200,
                                    gameFee: 0,
                                    prepay: false,
                                },
                            ]
                        )
                    ).to.be.revertedWith("invalid prepay settings");
                });

                it("lend single deck", async function () {
                    let beforeIds = await this.lendingMaster.getUserListedIds(
                        this.lender_1.address
                    );
                    let beforeNotListedIds =
                        await this.lendingMaster.getUserNotListedIds(
                            this.lender_1.address
                        );
                    await this.lendingMaster.connect(this.lender_1).lend(
                        [depositedIds[0]],
                        [
                            {
                                paymentToken: this.DAI.address,
                                prepayAmount: bigNum(30, 18),
                                lendDuration: 7,
                                winningRateForLender: 300,
                                winningRateForBorrower: 200,
                                gameFee: 0,
                                prepay: true,
                            },
                        ]
                    );
                    let afterIds = await this.lendingMaster.getUserListedIds(
                        this.lender_1.address
                    );
                    let afterNotListedIds =
                        await this.lendingMaster.getUserNotListedIds(
                            this.lender_1.address
                        );
                    expect(afterIds.length - beforeIds.length).to.be.equal(1);
                    expect(
                        beforeNotListedIds.length - afterNotListedIds.length
                    ).to.be.equal(1);

                    let depositIds_1 =
                        await this.lendingMaster.getUserDepositedIds(
                            this.lender_2.address
                        );
                    await this.lendingMaster.connect(this.lender_2).lend(
                        [depositIds_1[0]],
                        [
                            {
                                paymentToken: this.DAI.address,
                                prepayAmount: bigNum(30, 18),
                                lendDuration: 7,
                                winningRateForLender: 300,
                                winningRateForBorrower: 200,
                                gameFee: 0,
                                prepay: true,
                            },
                        ]
                    );
                });

                it("reverts if already listed", async function () {
                    await expect(
                        this.lendingMaster.connect(this.lender_1).lend(
                            [depositedIds[0]],
                            [
                                {
                                    paymentToken: this.DAI.address,
                                    prepayAmount: bigNum(30, 18),
                                    lendDuration: 7,
                                    winningRateForLender: 300,
                                    winningRateForBorrower: 200,
                                    gameFee: 0,
                                    prepay: true,
                                },
                            ]
                        )
                    ).to.be.revertedWith("already listed");
                });
            });

            describe("lend multi decks", function () {
                it("lend multi decks", async function () {
                    let notListedIds =
                        await this.lendingMaster.getUserNotListedIds(
                            this.lender_1.address
                        );
                    await this.lendingMaster.connect(this.lender_1).lend(
                        [notListedIds[0], notListedIds[1]],
                        [
                            {
                                paymentToken: this.USDT.address,
                                prepayAmount: 0,
                                lendDuration: 7,
                                winningRateForLender: 300,
                                winningRateForBorrower: 200,
                                gameFee: 0,
                                prepay: false,
                            },
                            {
                                paymentToken: this.Fevr.address,
                                prepayAmount: bigNum(30, 18),
                                lendDuration: 7,
                                winningRateForLender: 300,
                                winningRateForBorrower: 200,
                                gameFee: 0,
                                prepay: true,
                            },
                        ]
                    );
                });
            });
        });

        describe("borrow single collection and NLBundle", function () {
            describe("borrow single deck", function () {
                let totalListedIds;
                it("reverts if array length is zero", async function () {
                    await expect(
                        this.lendingMaster.connect(this.borrower_1).borrow([])
                    ).to.be.revertedWith("invalid length array");
                });

                it("reverts if deckId is not listed for lend", async function () {
                    await expect(
                        this.lendingMaster.connect(this.borrower_1).borrow([0])
                    ).to.be.revertedWith("not listed for lend");
                });

                it("reverts if not enough cost for borrow", async function () {
                    totalListedIds =
                        await this.lendingMaster.getTotalListedCollections();
                    await expect(
                        this.lendingMaster
                            .connect(this.borrower_1)
                            .borrow([totalListedIds[0]])
                    ).to.be.revertedWith("not enough for prepayment");
                });

                it("reverts if lender is not same", async function () {
                    await this.DAI.transfer(
                        this.borrower_1.address,
                        bigNum(1000, 18)
                    );
                    await this.USDT.transfer(
                        this.borrower_1.address,
                        bigNum(1000, 6)
                    );
                    let transferAmount = BigInt(
                        BigInt(
                            await this.Fevr.balanceOf(this.deployer.address)
                        ) / BigInt(2)
                    );
                    await this.Fevr.transfer(
                        this.borrower_1.address,
                        BigInt(transferAmount)
                    );

                    await this.DAI.connect(this.borrower_1).approve(
                        this.lendingMaster.address,
                        bigNum(1000, 18)
                    );
                    await this.USDT.connect(this.borrower_1).approve(
                        this.lendingMaster.address,
                        bigNum(1000, 6)
                    );
                    await this.Fevr.connect(this.borrower_1).approve(
                        this.lendingMaster.address,
                        BigInt(transferAmount)
                    );

                    let userListedIds_1 =
                        await this.lendingMaster.getUserListedIds(
                            this.lender_1.address
                        );
                    let userListedIds_2 =
                        await this.lendingMaster.getUserListedIds(
                            this.lender_2.address
                        );

                    await expect(
                        this.lendingMaster
                            .connect(this.borrower_1)
                            .borrow([userListedIds_1[0], userListedIds_2[0]], {
                                value: bigNum(1),
                            })
                    ).to.be.revertedWith("should be same lender");
                });

                it("borrow deck and check buyback and serviceFee", async function () {
                    let borrowDeckIds = [totalListedIds[0], totalListedIds[3]];

                    let borrowDuration = 5;
                    let req_1 = await this.lendingMaster.lendingReqsPerDeck(
                        borrowDeckIds[0]
                    );
                    let req_2 = await this.lendingMaster.lendingReqsPerDeck(
                        borrowDeckIds[1]
                    );

                    let prepayDAIAmount = req_1.prepayAmount;
                    let prepayFevrAmount = req_2.prepayAmount;

                    let beforeLenderDAIBal = await this.DAI.balanceOf(
                        this.lender_1.address
                    );
                    let beforeLenderFevrBal = await this.Fevr.balanceOf(
                        this.lender_1.address
                    );
                    let [beforeBorrowedIds, ,] =
                        await this.lendingMaster.getUserBorrowedIds(
                            this.borrower_1.address
                        );
                    let beforeProtocolFevrBal = await this.Fevr.balanceOf(
                        this.treasury.address
                    );
                    let beforeDEADFevrBal = await this.Fevr.balanceOf(
                        DEADWallet
                    );
                    await this.lendingMaster
                        .connect(this.borrower_1)
                        .borrow(borrowDeckIds, { value: bigNum(1) });
                    let [afterBorrowedIds, ,] =
                        await this.lendingMaster.getUserBorrowedIds(
                            this.borrower_1.address
                        );
                    let afterLenderDAIBal = await this.DAI.balanceOf(
                        this.lender_1.address
                    );
                    let afterLenderFevrBal = await this.Fevr.balanceOf(
                        this.lender_1.address
                    );
                    let afterProtocolFevrBal = await this.Fevr.balanceOf(
                        this.treasury.address
                    );
                    let afterDEADFevrBal = await this.Fevr.balanceOf(
                        DEADWallet
                    );

                    expect(
                        smallNum(
                            BigInt(afterLenderDAIBal) -
                                BigInt(beforeLenderDAIBal),
                            18
                        )
                    ).to.be.equal(smallNum(prepayDAIAmount, 18));
                    expect(
                        smallNum(
                            BigInt(afterLenderFevrBal) -
                                BigInt(beforeLenderFevrBal),
                            18
                        )
                    ).to.be.equal(smallNum(prepayFevrAmount, 18));
                    expect(
                        afterBorrowedIds.length - beforeBorrowedIds.length
                    ).to.be.equal(2);

                    expect(
                        smallNum(
                            BigInt(afterProtocolFevrBal) -
                                BigInt(beforeProtocolFevrBal),
                            18
                        )
                    ).to.be.greaterThan(0);
                    expect(
                        smallNum(
                            BigInt(afterDEADFevrBal) -
                                BigInt(beforeDEADFevrBal),
                            18
                        )
                    ).to.be.greaterThan(0);
                });

                it("reverts if already borrowed", async function () {
                    await expect(
                        this.lendingMaster
                            .connect(this.borrower_1)
                            .borrow([totalListedIds[0]])
                    ).to.be.revertedWith("already borrowed");
                });
            });
        });
    });

    describe("deposit LBundle and make LBundle", function () {
        describe("depositLBundle", function () {
            it("reverts if array length is zero", async function () {
                await expect(
                    this.lendingMaster
                        .connect(this.lender_1)
                        .depositCollection([], [], true)
                ).to.be.revertedWith("invalid length array");
            });

            it("reverts if array length is mismatch", async function () {
                await expect(
                    this.lendingMaster
                        .connect(this.lender_1)
                        .depositCollection(
                            [this.collection_1.address],
                            [],
                            true
                        )
                ).to.be.revertedWith("mismatch length array");
            });

            it("reverts if collection amount is over maxAmountForBundle", async function () {
                let collectionAddr = [];
                let tokenIds = [];

                for (let i = 1; i <= 50; i++) {
                    collectionAddr.push(this.collection_1.address);
                    tokenIds.push(i);
                }
                await expect(
                    this.lendingMaster
                        .connect(this.lender_1)
                        .depositCollection(collectionAddr, tokenIds, true)
                ).to.be.revertedWith("invalid deposit amount");
            });

            it("depositLBundle", async function () {
                let collectionAddr = [];
                let tokenIds = [];

                for (let i = 81; i <= 90; i++) {
                    collectionAddr.push(this.collection_1.address);
                    tokenIds.push(i);
                }

                let deckId = await this.lendingMaster.depositId();
                let beforeDepositedIds =
                    await this.lendingMaster.getUserDepositedIds(
                        this.lender_1.address
                    );
                /// reverts if LBundleMode is disabled.
                await expect(
                    this.lendingMaster
                        .connect(this.lender_1)
                        .depositCollection(collectionAddr, tokenIds, true)
                ).to.be.revertedWith("LBundleMode disabled");

                /// enable LBundleMode
                await expect(
                    this.lendingMaster
                        .connect(this.lender_1)
                        .enableLBundleMode(true)
                ).to.be.revertedWith("Ownable: caller is not the owner");
                await this.lendingMaster.enableLBundleMode(true);

                await this.lendingMaster
                    .connect(this.lender_1)
                    .depositCollection(collectionAddr, tokenIds, true);
                let afterDepositedIds =
                    await this.lendingMaster.getUserDepositedIds(
                        this.lender_1.address
                    );
                let collectionInfo = await this.lendingMaster.getCollectionInfo(
                    deckId
                );
                let [deckInfo, deckIds] =
                    await this.lendingMaster.getDepositInfo(deckId);

                expect(deckInfo.owner).to.be.equal(this.lender_1.address);
                expect(deckIds.length).to.be.equal(1);
                expect(deckIds[0]).to.be.equal(deckId);
                expect(collectionInfo.collections.length).to.be.equal(10);
                expect(
                    afterDepositedIds.length - beforeDepositedIds.length
                ).to.be.equal(1);
            });
        });

        describe("mergeDeposits", function () {
            it("reverts if array length is zero", async function () {
                await expect(
                    this.lendingMaster.connect(this.lender_1).mergeDeposits([])
                ).to.be.revertedWith("invalid length array");
            });

            it("reverts if deckId is invalid", async function () {
                await expect(
                    this.lendingMaster
                        .connect(this.lender_1)
                        .mergeDeposits([1000, 10001])
                ).to.be.revertedWith("invalid depositId");
            });

            it("reverts if deckId is borrowed", async function () {
                let [borrowedIds, ,] =
                    await this.lendingMaster.getUserBorrowedIds(
                        this.borrower_1.address
                    );
                await expect(
                    this.lendingMaster
                        .connect(this.lender_1)
                        .mergeDeposits([borrowedIds[0], 100])
                ).to.be.revertedWith("borrowed depositId");
            });

            it("reverts if deckId is already listed for lend", async function () {
                let listedIds = await this.lendingMaster.getUserListedIds(
                    this.lender_1.address
                );
                await expect(
                    this.lendingMaster
                        .connect(this.lender_1)
                        .mergeDeposits([listedIds[1], 100])
                ).to.be.revertedWith("listed for lend");
            });

            it("make LBundle", async function () {
                let notListedIds = await this.lendingMaster.getUserNotListedIds(
                    this.lender_1.address
                );
                let beforeListedIds = await this.lendingMaster.getUserListedIds(
                    this.lender_1.address
                );
                await this.lendingMaster
                    .connect(this.lender_1)
                    .mergeDeposits(notListedIds);
                let afterListedIds = await this.lendingMaster.getUserListedIds(
                    this.lender_1.address
                );
                notListedIds = await this.lendingMaster.getUserNotListedIds(
                    this.lender_1.address
                );

                expect(
                    afterListedIds.length - beforeListedIds.length
                ).to.be.equal(1);
                expect(notListedIds.length).to.be.equal(0);
            });
        });
    });

    describe("withdrawCollection", function () {
        it("reverts if array length is zero", async function () {
            await expect(
                this.lendingMaster.connect(this.lender_1).withdrawCollection([])
            ).to.be.revertedWith("invalid length array");
        });

        it("reverts if caller is not deck owner", async function () {
            let depositedIds = await this.lendingMaster.getUserDepositedIds(
                this.lender_1.address
            );
            await expect(
                this.lendingMaster
                    .connect(this.lender_2)
                    .withdrawCollection([depositedIds[0]])
            ).to.be.revertedWith("not deck owner");
        });

        it("reverts if depositId is borrowed", async function () {
            let [borrowedIds, ,] = await this.lendingMaster.getUserBorrowedIds(
                this.borrower_1.address
            );
            await expect(
                this.lendingMaster
                    .connect(this.lender_1)
                    .withdrawCollection([borrowedIds[0]])
            ).to.be.revertedWith("borrowed depositId");
        });

        it("withdrawCollection", async function () {
            let depositedIds = await this.lendingMaster.getUserDepositedIds(
                this.lender_1.address
            );
            await this.lendingMaster
                .connect(this.lender_1)
                .withdrawCollection([depositedIds[1]]);
            let afterDepositedIds =
                await this.lendingMaster.getUserDepositedIds(
                    this.lender_1.address
                );
            expect(depositedIds.length - afterDepositedIds.length).to.be.equal(
                1
            );
        });
    });

    describe("withdraw token", function () {
        it("reverts if caller is not the owner", async function () {
            await expect(
                this.treasury
                    .connect(this.lender_1)
                    .withdrawToken(this.DAI.address)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("reverts if no withdrawable amount", async function () {
            await expect(
                this.treasury.withdrawToken(this.USDC.address)
            ).to.be.revertedWith("no withdrawable amount");
        });

        it("withdrawToken", async function () {
            let beforeBal = await this.Fevr.balanceOf(this.deployer.address);
            await this.treasury.withdrawToken(this.Fevr.address);
            let afterBal = await this.Fevr.balanceOf(this.deployer.address);
            expect(
                smallNum(BigInt(afterBal) - BigInt(beforeBal), 18)
            ).to.be.greaterThan(0);
        });
    });
});
