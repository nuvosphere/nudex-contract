const { ethers, upgrades } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
	  const { deployer, rewardSource } = await getNamedAccounts();
	  const { deploy } = deployments;

	  console.log("Deploying NuvoLockUpgradeable with deployer:", deployer);

	  const NuvoLockUpgradeable = await ethers.getContractFactory("NuvoLockUpgradeable");
	  const nuvoLock = await upgrades.deployProxy(NuvoLockUpgradeable, [rewardSource], {
		      initializer: "initialize",
		    });

	  await nuvoLock.deployed();
	  console.log("NuvoLockUpgradeable deployed to:", nuvoLock.address);

	  return nuvoLock;
};

module.exports.tags = ["NuvoLock"];
