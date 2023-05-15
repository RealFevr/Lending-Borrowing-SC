const { ethers, upgrades, network } = require("hardhat");
const { getImplementationAddress } = require("@openzeppelin/upgrades-core");
const fs = require("fs");

const hour = 60 * 60;

const day = 24 * hour;

const updateAddress = async (contractName, contractAddreses) => {
    if (network.name == "localhost" || network.name == "hardhat") return;
    const addressDir = `${__dirname}/../deploy_address/${network.name}`;
    if (!fs.existsSync(addressDir)) {
        fs.mkdirSync(addressDir);
    }

    let data = "";
    if (contractAddreses.length == 2) {
        data = {
            contract: contractAddreses[0],
            proxyImp: contractAddreses[1],
        };
    } else {
        data = {
            contract: contractAddreses[0],
        };
    }

    fs.writeFileSync(
        `${addressDir}/${contractName}.txt`,
        JSON.stringify(data, null, 2)
    );
};

const getContractAddress = async (contractName, network_name) => {
    const addressDir = `${__dirname}/../deploy_address/${network_name}`;
    if (!fs.existsSync(addressDir)) {
        return "";
    }

    let data = fs.readFileSync(`${addressDir}/${contractName}.txt`);
    data = JSON.parse(data, null, 2);

    return data;
};

const getContract = async (contractName, contractMark, network_name) => {
    const addressDir = `${__dirname}/../deploy_address/${network_name}`;
    if (!fs.existsSync(addressDir)) {
        return "";
    }

    let data = fs.readFileSync(`${addressDir}/${contractMark}.txt`);
    data = JSON.parse(data, null, 2);

    return await getAt(contractName, data.contract);
};

const deploy = async (contractName, contractMark, ...args) => {
    const factory = await ethers.getContractFactory(contractName);
    const contract = await factory.deploy(...args);
    await contract.deployed();
    await verify(contract.address, [...args]);
    console.log(contractName, contract.address);
    await updateAddress(contractMark, [contract.address]);
    return contract;
};

const deployProxy = async (contractName, contractMark, args = []) => {
    const factory = await ethers.getContractFactory(contractName);
    const contract = await upgrades.deployProxy(factory, args, {
        unsafeAllow: ["delegatecall", "constructor"],
    });
    await contract.deployed();
    const implAddress = await getImplementationAddress(
        ethers.provider,
        contract.address
    );
    await verify(implAddress, args);
    await updateAddress(contractMark, [contract.address, implAddress]);
    console.log(contractName, contract.address, implAddress);
    return contract;
};

const upgradeProxy = async (contractName, contractAddress) => {
    const factory = await ethers.getContractFactory(contractName);
    const contract = await upgrades.upgradeProxy(contractAddress, factory, {
        unsafeAllow: ["delegatecall", "constructor"],
    });
    await contract.deployed();
    console.log(contractName, contract.address);
    return contract;
};

const getAt = async (contractName, contractAddress) => {
    return await ethers.getContractAt(contractName, contractAddress);
};

const verify = async (contractAddress, args = []) => {
    if (network.name == "localhost" || network.name == "hardhat") return;
    try {
        console.log("verifying...");
        await hre.run("verify:verify", {
            address: contractAddress,
            constructorArguments: args,
        });
    } catch (ex) {
        console.log(ex);
    }
};

const getCurrentTimestamp = async () => {
    return (await ethers.provider.getBlock("latest")).timestamp;
};

const spendTime = async (spendSeconds) => {
    await network.provider.send("evm_increaseTime", [spendSeconds]);
    await network.provider.send("evm_mine");
};

const getETHBalance = async (walletAddress) => {
    return await ethers.provider.getBalance(walletAddress);
};

const bigNum = (num, decimals = 18) => num + "0".repeat(decimals);

const bigNum_6 = (num) => num + "0".repeat(6);

const bigNum_8 = (num) => num + "0".repeat(8);

const smallNum = (num, decimals = 18) => parseInt(num) / bigNum(1, decimals);

const smallNum_6 = (num) => parseInt(num) / bigNum_6(1);

const smallNum_8 = (num) => parseInt(num) / bigNum_8(1);

module.exports = {
    getAt,
    deploy,
    deployProxy,
    upgradeProxy,
    getContractAddress,
    getContract,
    getCurrentTimestamp,
    spendTime,
    getETHBalance,
    bigNum,
    bigNum_6,
    bigNum_8,
    smallNum,
    smallNum_6,
    smallNum_8,
    hour,
    day,
};
