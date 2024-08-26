const { ethers } = require("hardhat");

async function setupContracts() {
    const [deployer, admin, member1, member2, multisigWallet] = await ethers.getSigners();

    // Deploy Proxy contract
    const Proxy = await ethers.getContractFactory("Proxy");
    const logicContract = await ethers.getContractFactory("NuvoDAOLogic");
    const logicInstance = await logicContract.deploy(
        // Constructor parameters for NuvoDAOLogic
        admin.address,
        multisigWallet.address,
        20, // quorumPercentage
        ethers.utils.parseEther("1"), // proposalFee
        60 * 60 * 24, // executionDelay (1 day)
        ethers.utils.parseEther("100"), // fundingThreshold
        1 // reputationDecayRate
    );
    await logicInstance.deployed();

    const proxy = await Proxy.deploy(logicInstance.address);
    await proxy.deployed();

    // Attach proxy to logic
    const dao = await logicContract.attach(proxy.address);

    return { deployer, admin, member1, member2, multisigWallet, dao, proxy };
}

module.exports = {
    setupContracts,
};
