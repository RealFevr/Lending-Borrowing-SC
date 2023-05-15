const { deploy } = require("./utils");
const { getDeploymentParam } = require("./params");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("deploy wallet address: ", deployer.address);

    await deploy(
        "LendingMaster",
        "LendingMaster",
        param.fevrTokenAddress,
        param.routerAddress
    );

    console.log("deployed successfully!");
}

main();
