const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NuvoLockUpgradeable - Unlocking", function () {
  let nuvoLock, nuvoToken, rewardSource, owner, addr1, addr2;
  const lockAmount = ethers.parseUnits("100", 18);
  const lockPeriod = 7 * 24 * 60 * 60; // 1 week

  beforeEach(async function () {
    [owner, addr1, addr2, rewardSource] = await ethers.getSigners();

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

    // Mint tokens to addr1 for testing
    await nuvoToken.mint(addr1.address, ethers.parseUnits("1000", 18));

    // Lock tokens for addr1
    await nuvoToken.connect(addr1).approve(await nuvoLock.getAddress(), lockAmount);
    await nuvoLock.connect(addr1).lock(lockAmount, lockPeriod);
  });

  it("Should allow a user to unlock tokens after the lock period", async function () {
    // Increase time to after the lock period
    await ethers.provider.send("evm_increaseTime", [lockPeriod + 1]);
    await ethers.provider.send("evm_mine");

    await expect(nuvoLock.connect(addr1).unlock())
      .to.emit(nuvoLock, "Unlocked")
      .withArgs(addr1.address, lockAmount);

    const lockInfo = await nuvoLock.getLockInfo(addr1.address);
    expect(lockInfo.amount).to.equal(0);
  });

  it("Should revert if tokens are still locked", async function () {
    await expect(nuvoLock.connect(addr1).unlock()).to.be.revertedWith("Tokens are still locked");
  });

  it("Should revert if called by non-participant", async function () {
    await expect(nuvoLock.connect(addr2).unlock()).to.be.revertedWith("Not a participant");
  });
});
