const { network } = require("hardhat");
const uniswapRouterAddr = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
const pancakeswapRouterAddr = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
const pancakeswapRouterAddr_test = "0x9ac64cc6e4415144c455bd8e4837fea55603e5c3";

const DEPLOYMENT_PARAM = {
    mainnet: {
        fevrTokenAddress: "0x9fb83c0635de2e815fd1c21b3a292277540c2e8d",
        routerAddress: uniswapRouterAddr
    },
    goerli: {
        fevrTokenAddress: "",
        routerAddress: uniswapRouterAddr
    },
    bsc_mainnet: {
        fevrTokenAddress: "0x82030CDBD9e4B7c5bb0b811A61DA6360D69449cc",
        routerAddress: pancakeswapRouterAddr
    },
    bsc_testnet: {
        fevrTokenAddress: "",
        routerAddress: pancakeswapRouterAddr_test
    }
}

const getDeploymentParam = () => {
    if (network.name == "goerli") {
        return DEPLOYMENT_PARAM.goerli;
    } else if (network.name == "mainnet") {
        return DEPLOYMENT_PARAM.mainnet;
    } else if (network.name == "bsc_mainnet") {
        return DEPLOYMENT_PARAM.bsc_mainnet;
    } else if (network.name == "bsc_testnet") {
        return DEPLOYMENT_PARAM.bsc_testnet;
    } else {
        return {};
    }
}

module.exports = {
    getDeploymentParam    
};