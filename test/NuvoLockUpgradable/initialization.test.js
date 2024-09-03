const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NuvoLockUpgradeable - Initialization", function () {
  let nuvoLock, nuvoToken, rewardSource, owner, addr1;

  beforeEach(async function () {
    [owner, addr1, rewardSource] = await ethers.getSigners();

    // Deploy mock NuvoToken
    const MockNuvoToken = await ethers.getContractFactory("MockNuvoToken");
    nuvoToken = await MockNuvoToken.deploy();
    await nuvoToken.waitForDeployment();

    // Deploy NuvoLockUpgradeable
    const NuvoLockUpgradeable = await ethers.getContractFactory("NuvoLockUpgradeable");
    nuvoLock = await upgrades.deployProxy(
      NuvoLockUpgradeable,
      [await nuvoToken.getAddress(), await rewardSource.getAddress(), await owner.getAddress()],
      { initializer: "initialize" }
    );
    await nuvoLock.waitForDeployment();
  });

  it("Should initialize with correct parameters", async function () {
    expect(await nuvoLock.nuvoToken()).to.equal(await nuvoToken.getAddress());
    expect(await nuvoLock.rewardSource()).to.equal(await rewardSource.getAddress());
    expect(await nuvoLock.owner()).to.equal(await owner.getAddress());
    expect(await nuvoLock.currentPeriodStart()).to.be.gt(0);
    expect(await nuvoLock.currentPeriod()).to.equal(0);
  });

  it("Should only allow owner to initialize", async function () {
    const NuvoLockUpgradeable = await ethers.getContractFactory("NuvoLockUpgradeable");
    await expect(
      upgrades.deployProxy(
        NuvoLockUpgradeable,
        [await nuvoToken.getAddress(), await rewardSource.getAddress(), addr1.address],
        { initializer: "initialize" }
      )
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });
});
