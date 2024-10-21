const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NuvoLockUpgradeable - Bonus and Demerit Points", function () {
  let nuvoLock, nuvoToken, rewardSource, owner, addr1, addr2, address1, address2;
  const lockAmount = ethers.parseUnits("100", 18);
  const lockPeriod = 7 * 24 * 60 * 60; // 1 week

  beforeEach(async function () {
    [owner, addr1, addr2, rewardSource] = await ethers.getSigners();
    address1 = await addr1.getAddress();
    address2 = await addr2.getAddress();

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

    // Lock tokens for addr1
    await nuvoToken.connect(addr1).approve(await nuvoLock.getAddress(), lockAmount);
    await nuvoLock.connect(addr1).lock(lockAmount, lockPeriod);
  });

  it("Should accumulate bonus points for a participant", async function () {
    await nuvoLock.connect(owner).accumulateBonusPoints(address1);

    const lockInfo = await nuvoLock.getLockInfo(address1);
    expect(lockInfo.bonusPoints).to.equal(1);
  });

  it("Should accumulate demerit points for a participant", async function () {
    await nuvoLock.connect(owner).accumulateDemeritPoints(address1);

    const lockInfo = await nuvoLock.getLockInfo(address1);
    expect(lockInfo.demeritPoints).to.equal(1);
  });

  it("Should only allow owner to accumulate bonus points", async function () {
    await expect(
      nuvoLock.connect(addr1).accumulateBonusPoints(address2)
    ).to.be.revertedWithCustomError(nuvoLock, "OwnableUnauthorizedAccount");
  });

  it("Should only allow owner to accumulate demerit points", async function () {
    await expect(
      nuvoLock.connect(addr1).accumulateDemeritPoints(address2)
    ).to.be.revertedWithCustomError(nuvoLock, "OwnableUnauthorizedAccount");
  });

  it("Should correctly adjust rewards based on bonus and demerit points", async function () {
    // Accumulate bonus and demerit points
    await nuvoLock.connect(owner).accumulateBonusPoints(address1);
    await nuvoLock.connect(owner).accumulateDemeritPoints(address1);

    const lockInfo = await nuvoLock.getLockInfo(address1);
    const adjustedBonusPoints =
      lockInfo.bonusPoints > lockInfo.demeritPoints
        ? lockInfo.bonusPoints - lockInfo.demeritPoints
        : 0;

    expect(adjustedBonusPoints).to.equal(0);
  });
});
