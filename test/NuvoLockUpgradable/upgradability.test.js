const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("NuvoLockUpgradeable - Upgrade Functionality", function () {
  let nuvoLock, nuvoLockV2, nuvoToken, rewardSource, owner, addr1;

  beforeEach(async function () {
    [owner, addr1, rewardSource] = await ethers.getSigners();

    // Deploy mock NuvoToken
    const MockNuvoToken = await ethers.getContractFactory("MockNuvoToken");
    nuvoToken = await MockNuvoToken.deploy();
    await nuvoToken.deployed();

    // Deploy the initial version of NuvoLockUpgradeable
    const NuvoLockUpgradeable = await ethers.getContractFactory("NuvoLockUpgradeable");
    nuvoLock = await upgrades.deployProxy(NuvoLockUpgradeable, [nuvoToken.address, rewardSource.address, owner.address], { initializer: "initialize" });
    await nuvoLock.deployed();
  });

  it("Should allow contract to be upgraded by the owner", async function () {
    // Deploy the upgraded version of NuvoLockUpgradeable
    const NuvoLockUpgradeableV2 = await ethers.getContractFactory("NuvoLockUpgradeableV2");
    nuvoLockV2 = await upgrades.upgradeProxy(nuvoLock.address, NuvoLockUpgradeableV2);

    // Verify that the upgrade was successful and the new functionality is accessible
    expect(await nuvoLockV2.newFunctionality()).to.equal("New functionality");
  });

  it("Should revert if non-owner tries to upgrade", async function () {
    // Attempt to upgrade the contract as a non-owner
    const NuvoLockUpgradeableV2 = await ethers.getContractFactory("NuvoLockUpgradeableV2");
    await expect(upgrades.upgradeProxy(nuvoLock.address, NuvoLockUpgradeableV2.connect(addr1))).to.be.revertedWith("Ownable: caller is not the owner");
  });
});
