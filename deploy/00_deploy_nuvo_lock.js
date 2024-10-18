const { ethers, upgrades } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deployer, rewardSource } = await getNamedAccounts();
  const { deploy } = deployments;

  console.log("Deploying NuvoLockUpgradeable with deployer:", deployer);

  const NuvoLockUpgradeable = await ethers.getContractFactory("NuvoLockUpgradeable");
  const nuvoLock = await upgrades.deployProxy(NuvoLockUpgradeable, [rewardSource], {
    initializer: "initialize",
  });

  await nuvoLock.waitForDeployment();
  console.log("NuvoLockUpgradeable deployed to:", await nuvoLock.getAddress());

  return nuvoLock;
};

module.exports.tags = ["NuvoLock"];
