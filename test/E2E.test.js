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
} = require("../scripts/utils");

describe("Lending-Borrowing Protocol test", function () {
    let uniswapRouterAddress = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
    let fevrAddress = "0x9fB83c0635De2E815fd1c21b3a292277540C2e8d";
    let daiAddress = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
    let usdtAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
    let usdcAddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
    let WETH;

    before(async function () {
        [this.owner, this.user_1, this.user_2, this.user_3] =
            await ethers.getSigners();
        this.dexRouter = new ethers.Contract(
            uniswapRouterAddress,
            uniswap_abi,
            this.owner
        );
        this.DAI = new ethers.Contract(daiAddress, erc20_abi, this.owner);
        this.Fevr = new ethers.Contract(fevrAddress, erc20_abi, this.owner);
        this.USDT = new ethers.Contract(usdtAddress, erc20_abi, this.owner);
        this.USDC = new ethers.Contract(usdcAddress, erc20_abi, this.owner);

        this.lendingMaster = await deploy(
            "LendingMaster",
            "LendingMaster",
            this.Fevr.address,
            this.dexRouter.address
        );
        this.bundleNFT = await deploy("MockBundles", "MockBundles");
        this.collectionId_1 = await deploy(
            "MockCollectionId",
            "MockCollectionId"
        );
        this.collectionId_2 = await deploy(
            "MockCollectionId",
            "MockCollectionId"
        );
        WETH = await this.dexRouter.WETH();
    });

    it("check deployment", async function () {
        console.log("deployed successfully!");
    });

    it("swap ETH to USDT, DAI and Fevr", async function () {
        let decimals = await this.USDT.decimals();
        console.log("USDT decimals", decimals);
        let beforeBal = await this.USDT.balanceOf(this.owner.address);
        await this.dexRouter.swapExactETHForTokens(
            0,
            [WETH, this.USDT.address],
            this.owner.address,
            BigInt(await getCurrentTimestamp()) + BigInt(100),
            { value: bigNum(100) }
        );
        let afterBal = await this.USDT.balanceOf(this.owner.address);
        console.log(
            "received USDT amount: ",
            smallNum(BigInt(afterBal) - BigInt(beforeBal), decimals)
        );

        decimals = await this.DAI.decimals();
        beforeBal = await this.DAI.balanceOf(this.owner.address);
        await this.dexRouter.swapExactETHForTokens(
            0,
            [WETH, this.DAI.address],
            this.owner.address,
            BigInt(await getCurrentTimestamp()) + BigInt(100),
            { value: bigNum(100) }
        );
        afterBal = await this.DAI.balanceOf(this.owner.address);
        console.log(
            "received DAI amount: ",
            smallNum(BigInt(afterBal) - BigInt(beforeBal), decimals)
        );

        decimals = await this.Fevr.decimals();
        beforeBal = await this.Fevr.balanceOf(this.owner.address);
        await this.dexRouter.swapExactETHForTokens(
            0,
            [WETH, this.Fevr.address],
            this.owner.address,
            BigInt(await getCurrentTimestamp()) + BigInt(100),
            { value: bigNum(100) }
        );
        afterBal = await this.Fevr.balanceOf(this.owner.address);
        console.log(
            "received Fevr amount: ",
            smallNum(BigInt(afterBal) - BigInt(beforeBal), decimals)
        );
    });

    describe("setAcceptableERC20", function () {
        it("reverts if caller is not the owner", async function () {});

        it("reverts if array length is zero", async function () {});

        it("reverts if already removed", async function () {});

        it("add acceptable tokens", async function () {});

        it("reverts if already added", async function () {});
    });

    describe("setApprovedCollections", function () {
        it("reverts if caller is not the owner", async function () {});

        it("reverts if array length is zero", async function () {});

        it("reverts if already removed", async function () {});

        it("add acceptable collections", async function () {});

        it("reverts if already added", async function () {});
    });

    describe("setNLBundles", function () {
        it("reverts if caller is not the owner", async function () {});

        it("reverts if array length is zero", async function () {});

        it("reverts if already removed", async function () {});

        it("add acceptable NLBundles", async function () {});

        it("reverts if already added", async function () {});
    });

    describe("set service fee and link it to collection", function () {
        describe("set service fee", function () {
            it("reverts if caller is not the owner", async function () {});

            it("reverts if burnPercent is over 100%", async function () {});

            it("reverts if feeAmount is zero", async function () {});

            it("setServiceFee", async function () {});
        });

        describe("linkServiceFee", function () {
            it("reverts if caller is not the owner", async function () {});

            it("reverts if serviceFeeId is invalid", async function () {});

            it("reverts if collection is not acceptable", async function () {});

            it("linkServiceFee", async function () {});

            it("reverts if serviceFee is already linked", async function () {});
        });
    });

    describe("setMaxAmountForBundle", function () {
        it("reverts if caller is not the owner", async function () {});

        it("reverts if maxAmountForBundle is zero", async function () {});

        it("setMaxAmountForBundle", async function () {});
    });

    describe("setDepositFlag", function () {
        it("reverts if caller is not the owner", async function () {});

        it("reverts if collection is not approved", async function () {});

        it("setDepositFlag", async function () {});
    });

    describe("set buybackFee settings", function () {
        describe("buybackFeeTake", function () {
            it("reverts if caller is not the owner", async function () {});

            it("reverts if token is not approved", async function () {});

            it("buybackFeeTake", async function () {});
        });

        describe("setBuybackFee", function () {
            it("reverts if caller is not the owner", async function () {});

            it("reverts if token is not approved", async function () {});

            it("setBuybackFee", async function () {});
        });
    });

    describe("deposit collection and NLBundle", function () {
        describe("deposit collection", function () {
            it("reverts if array length is zero", async function () {});

            it("reverts array length is mismatch", async function () {});

            it("reverts if collection is not allowed", async function () {});

            it("reverts if collection owner is not caller", async function () {});

            it("reverts deposit limit exceeds", async function () {});

            it("deposit collections", async function () {});
        });

        describe("deposit NLBundle", function () {
            it("reverts if NLBundle is not approved", async function () {});

            it("reverts if NLBundle owner is not caller", async function () {});

            it("reverts if bundle contains collection amount is over max amount", async function () {});

            it("deposit NLBundle", async function () {});

            it("reverts if deposit limit exceeds", async function () {});
        });
    });

    describe("lend & borrow single collection and NLBundle", function () {
        describe("lend single collection and NLBundle", function () {
            describe("lend single deck", function () {
                it("reverts if caller is not deck owner", async function () {});

                it("reverts if payment token is not allowed", async function () {});

                it("reverts if dailyInterest is zero", async function () {});

                it("reverts if maxDuration is zero", async function () {});

                it("reverts if prepay setting is incorrect", async function () {});

                it("lend single deck", async function () {});

                it("reverts if already listed", async function () {});
            });

            describe("lend multi decks", function () {
                it("lend multi decks", async function () {});
            });
        });

        describe("borrow single collection and NLBundle", function () {
            describe("borrow single deck", function () {
                it("reverts if array length is zero", async function () {});

                it("reverts if borrow duration is zero", async function () {});

                it("reverts if deckId is not listed for lend", async function () {});

                it("reverts if lender is not same", async function () {});

                it("reverts if duration exceeds to max duration", async function () {});

                it("reverts if not enough cost for borrow", async function () {});

                it("borrow deck and check buyback and serviceFee", async function () {});

                it("reverts if already borrowed", async function () {});
            });

            describe("borrow multi decks", function () {
                it("borrow deck and check buyback and serviceFee", async function () {});
            });
        });
    });

    describe("deposit LBundle and make LBundle", function () {
        describe("depositLBundle", function () {
            it("reverts if array length is zero", async function () {});

            it("reverts if array length is mismatch", async function () {});

            it("reverts if collection amount is over maxAmountForBundle", async function () {});

            it("depositLBundle", async function () {});
        });

        describe("makeLBundle", function () {
            it("reverts if array length is zero", async function () {});

            it("reverts if deckId is invalid", async function () {});

            it("reverts if deckId is borrowed", async function () {});

            it("reverts if deckId is already listed for lend", async function () {});

            it("make LBundle", async function () {});
        });
    });

    describe("lend & borrow LBundle", function () {
        it("lend LBundle deck", async function () {});

        it("borrow LBundle deck and check buyback and service fee", async function () {});
    });

    describe("withdrawCollection", function () {
        it("reverts if array length is zero", async function () {});

        it("reverts if caller is not deck owner", async function () {});

        it("reverts if deckId is borrowed", async function () {});

        it("reverts if there is claimable interest with the deckId", async function () {});

        it("withdrawCollection", async function () {});
    });

    describe("claimLendingInterest", function () {
        it("reverts if deckId does not exist", async function () {});

        it("reverts if caller is not correct lender", async function () {});

        it("reverts if current is before maturity", async function () {});

        it("reverts if there is not claimable amount", async function () {});

        it("claimLendingInterest", async function () {});
    });
});
