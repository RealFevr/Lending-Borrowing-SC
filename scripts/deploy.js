const { deploy } = require("./utils");
const { getDeploymentParam } = require('./params');

async function main() {
    const [
        deployer
    ] = await ethers.getSigners();
    console.log("deploy wallet address: ", deployer.address);

    let collectionManager = await deploy("CollectionManager", "CollectionManager");
    let serviceManager = await deploy("ServiceManager", "ServiceManager");
    let param = getDeploymentParam();
    await deploy(
        "DeckMaster",
        "DeckMaster",
        param.fevrTokenAddress,
        collectionManager.address,
        serviceManager.address,
        param.routerAddress
    );
    
    console.log("deployed successfully!");
}

main();