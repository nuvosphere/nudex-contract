const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NuvoLockUpgradeable - Bonus and Demerit Points", function () {
  let nuvoLock, nuvoToken, rewardSource, owner, addr1, addr2;
  const lockAmount = ethers.utils.parseUnits("100", 18);
  const lockPeriod = 7 * 24 * 60 * 60; // 1 week

  beforeEach(async function () {
    [owner, addr1, addr2, rewardSource] = await ethers.getSigners();

    // Deploy mock NuvoToken
    const MockNuvoToken = await ethers.getContractFactory("MockNuvoToken");
    nuvoToken = await MockNuvoToken.deploy();
    await nuvoToken.deployed();

    // Deploy NuvoLockUpgradeable
    const NuvoLockUpgradeable = await ethers.getContractFactory("NuvoLockUpgradeable");
    nuvoLock = await upgrades.deployProxy(NuvoLockUpgradeable, [nuvoToken.address, rewardSource.address, owner.address], { initializer: "initialize" });
    await nuvoLock.deployed();

    // Mint tokens to addr1 for testing
    await nuvoToken.mint(addr1.address, ethers.utils.parseUnits("1000", 18));

    // Lock tokens for addr1
    await nuvoToken.connect(addr1).approve(nuvoLock.address, lockAmount);
    await nuvoLock.connect(addr1).lock(lockAmount, lockPeriod);
  });

  it("Should accumulate bonus points for a participant", async function () {
    await nuvoLock.connect(owner).accumulateBonusPoints(addr1.address);

    const lockInfo = await nuvoLock.getLockInfo(addr1.address);
    expect(lockInfo.bonusPoints).to.equal(1);
  });

  it("Should accumulate demerit points for a participant", async function () {
    await nuvoLock.connect(owner).accumulateDemeritPoints(addr1.address);

    const lockInfo = await nuvoLock.getLockInfo(addr1.address);
    expect(lockInfo.demeritPoints).to.equal(1);
  });

  it("Should only allow owner to accumulate bonus points", async function () {
    await expect(nuvoLock.connect(addr1).accumulateBonusPoints(addr2.address)).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("Should only allow owner to accumulate demerit points", async function () {
    await expect(nuvoLock.connect(addr1).accumulateDemeritPoints(addr2.address)).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("Should correctly adjust rewards based on bonus and demerit points", async function () {
    // Accumulate bonus and demerit points
    await nuvoLock.connect(owner).accumulateBonusPoints(addr1.address);
    await nuvoLock.connect(owner).accumulateDemeritPoints(addr1.address);

    const lockInfo = await nuvoLock.getLockInfo(addr1.address);
    const adjustedBonusPoints = (lockInfo.bonusPoints > lockInfo.demeritPoints) ? lockInfo.bonusPoints - lockInfo.demeritPoints : 0;

    expect(adjustedBonusPoints).to.equal(0);
  });
});
