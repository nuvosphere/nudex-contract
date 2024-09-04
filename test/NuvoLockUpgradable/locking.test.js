const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NuvoLockUpgradeable - Locking", function () {
  let nuvoLock, nuvoToken, rewardSource, owner, addr1, addr2, address1, address2;
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
    await nuvoToken.mint(address1, ethers.parseUnits("1000", 18));
  });

  it("Should allow a user to lock tokens", async function () {
    await nuvoToken.connect(addr1).approve(await nuvoLock.getAddress(), lockAmount);
    await expect(nuvoLock.connect(addr1).lock(lockAmount, lockPeriod))
      .to.emit(nuvoLock, "Locked")
      .withArgs(
        address1,
        lockAmount,
        (await ethers.provider.getBlock("latest")).timestamp + lockPeriod
      );

    const lockInfo = await nuvoLock.getLockInfo(address1);
    expect(lockInfo.amount).to.equal(lockAmount);
    expect(lockInfo.unlockTime).to.be.gt(0);
    expect(lockInfo.bonusPoints).to.equal(0);
    expect(lockInfo.accumulatedRewards).to.equal(0);
  });

  it("Should revert if lock period is too short", async function () {
    await nuvoLock.setMinLockPeriod(7 * 24 * 60 * 60); // one week
    const shortPeriod = 1 * 24 * 60 * 60; // 1 day
    await nuvoToken.connect(addr1).approve(await nuvoLock.getAddress(), lockAmount);
    await expect(nuvoLock.connect(addr1).lock(lockAmount, shortPeriod)).to.be.revertedWith(
      "Lock period is too short"
    );
  });

  it("Should revert if amount is zero", async function () {
    await expect(nuvoLock.connect(addr1).lock(0, lockPeriod)).to.be.revertedWith(
      "Amount must be greater than 0"
    );
  });

  it("Should revert if already locked", async function () {
    await nuvoToken.connect(addr1).approve(await nuvoLock.getAddress(), lockAmount);
    await nuvoLock.connect(addr1).lock(lockAmount, lockPeriod);
    await expect(nuvoLock.connect(addr1).lock(lockAmount, lockPeriod)).to.be.revertedWith(
      "Already locked"
    );
  });
});
