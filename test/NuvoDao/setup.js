const { ethers, upgrades } = require("hardhat");

async function setupContracts() {
  const [deployer, admin, member1, member2, multisigWallet] = await ethers.getSigners();
  let adminAddress = await admin.getAddress();

  // Deploy NuvoLockUpgradeable
  const MockNuvoToken = await ethers.getContractFactory("MockNuvoToken");
  nuvoToken = await MockNuvoToken.deploy();
  await nuvoToken.waitForDeployment();
  const NuvoLockUpgradeable = await ethers.getContractFactory("NuvoLockUpgradeable");
  nuvoLock = await upgrades.deployProxy(
    NuvoLockUpgradeable,
    [await nuvoToken.getAddress(), adminAddress, adminAddress],
    { initializer: "initialize" }
  );
  await nuvoLock.waitForDeployment();

  const logicContract = await ethers.getContractFactory("NuvoDAOLogic");
  const logicInstance = await logicContract.deploy(
    // Constructor parameters for NuvoDAOLogic
    adminAddress, // contract owner
    await nuvoLock.getAddress(), // nuvolock
    multisigWallet.address, // multisig wallet
    20, // quorumPercentage
    ethers.parseEther("1"), // proposalFee
    60 * 60 * 24, // executionDelay (1 day)
    ethers.parseEther("100"), // fundingThreshold
    1, // reputationDecayRate
    // FIXME: logic contract referencing the proxy?
    ethers.ZeroAddress, // proxy address
    ethers.ZeroAddress // proxy admin
  );
  await logicInstance.waitForDeployment();

  // Deploy Proxy contract
  const Proxy = await ethers.getContractFactory("Proxy");
  const proxy = await Proxy.deploy(await logicInstance.getAddress());
  await proxy.waitForDeployment();

  // Attach proxy to logic
  const dao = await logicContract.attach(await proxy.getAddress());

  return { deployer, admin, member1, member2, multisigWallet, dao, proxy };
}

module.exports = {
  setupContracts,
};
