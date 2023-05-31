const { deploy } = require("./utils");
const { getDeploymentParam } = require("./params");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("deploy wallet address: ", deployer.address);

    const treasury = await deploy(
        "Treasury",
        "Treasury",
        param.fevrTokenAddress,
        param.routerAddress
    );

    const lendingMaster = await deploy(
        "LendingMaster",
        "LendingMaster",
        treasury.address
    );

    console.log("deployed successfully!");

    console.log("initializing treasury contract...");
    let tx = await treasury.setLendingMaster(lendingMaster.address);
    console.log("initialized successfully!");
}

main();
