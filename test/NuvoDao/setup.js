const { ethers, upgrades } = require("hardhat");

async function setupContracts() {
  const MIN_LOCK_AMOUNT = BigInt(10000 * 10 ** 18);
  const MIN_LOCK_DURATION = 60 * 60 * 24 * 3; // 3 days
  const [deployer, admin, member1, member2, multisigWallet] = await ethers.getSigners();
  let adminAddress = await admin.getAddress();

  // Deploy Mock Token
  const MockNuvoToken = await ethers.getContractFactory("MockNuvoToken");
  nuvoToken = await MockNuvoToken.deploy();
  await nuvoToken.waitForDeployment();
  await nuvoToken.mint(await member1.getAddress(), MIN_LOCK_AMOUNT);
  await nuvoToken.mint(await member2.getAddress(), MIN_LOCK_AMOUNT);

  // Deploy NuvoLockUpgradeable
  const NuvoLockUpgradeable = await ethers.getContractFactory("NuvoLockUpgradeable");
  nuvoLock = await upgrades.deployProxy(
    NuvoLockUpgradeable,
    [await nuvoToken.getAddress(), adminAddress, adminAddress],
    { initializer: "initialize" }
  );
  await nuvoLock.waitForDeployment();

  await nuvoToken.connect(member1).approve(await nuvoLock.getAddress(), MIN_LOCK_AMOUNT);
  await nuvoLock.connect(member1).lock(MIN_LOCK_AMOUNT, MIN_LOCK_DURATION);

  const logicContract = await ethers.getContractFactory("NuvoDAOLogic");
  // Constructor parameters for NuvoDAOLogic
  const logicInstance = await logicContract.deploy();
  await logicInstance.waitForDeployment();

  // Deploy Proxy contract
  const Proxy = await ethers.getContractFactory("Proxy");
  const proxy = await Proxy.deploy(await logicInstance.getAddress());
  await proxy.waitForDeployment();

  // Attach proxy to logic
  const dao = await logicContract.attach(await proxy.getAddress());

  // initialize proxy
  await dao.initialize(
    adminAddress, // contract owner
    await nuvoLock.getAddress(), // nuvolock
    multisigWallet.address, // multisig wallet
    20, // quorumPercentage
    ethers.parseEther("1"), // proposalFee
    60 * 60 * 24, // executionDelay (1 day)
    ethers.parseEther("100"), // fundingThreshold
    1, // reputationDecayRate
    // FIXME: logic contract referencing the proxy?
    await proxy.getAddress() // proxy address
  );

  return {
    MIN_LOCK_AMOUNT,
    MIN_LOCK_DURATION,
    deployer,
    admin,
    member1,
    member2,
    multisigWallet,
    dao,
    proxy,
    nuvoToken,
    nuvoLock,
  };
}

module.exports = {
  setupContracts,
};
