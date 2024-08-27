const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NuvoLockUpgradeable - Initialization", function () {
  let nuvoLock, nuvoToken, rewardSource, owner, addr1;
  
  beforeEach(async function () {
    [owner, addr1, rewardSource] = await ethers.getSigners();

    // Deploy mock NuvoToken
    const MockNuvoToken = await ethers.getContractFactory("MockNuvoToken");
    nuvoToken = await MockNuvoToken.deploy();
    await nuvoToken.deployed();

    // Deploy NuvoLockUpgradeable
    const NuvoLockUpgradeable = await ethers.getContractFactory("NuvoLockUpgradeable");
    nuvoLock = await upgrades.deployProxy(NuvoLockUpgradeable, [nuvoToken.address, rewardSource.address, owner.address], { initializer: "initialize" });
    await nuvoLock.deployed();
  });

  it("Should initialize with correct parameters", async function () {
    expect(await nuvoLock.nuvoToken()).to.equal(nuvoToken.address);
    expect(await nuvoLock.rewardSource()).to.equal(rewardSource.address);
    expect(await nuvoLock.owner()).to.equal(owner.address);
    expect(await nuvoLock.currentPeriodStart()).to.be.gt(0);
    expect(await nuvoLock.currentPeriod()).to.equal(0);
  });

  it("Should only allow owner to initialize", async function () {
    const NuvoLockUpgradeable = await ethers.getContractFactory("NuvoLockUpgradeable");
    await expect(
      upgrades.deployProxy(NuvoLockUpgradeable, [nuvoToken.address, rewardSource.address, addr1.address], { initializer: "initialize" })
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });
});
