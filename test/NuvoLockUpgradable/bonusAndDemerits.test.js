const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NuvoLockUpgradeable - Bonus and Demerit Points Accumulation", function () {
  let nuvoLock, nuvoToken, owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    // Deploy mock NuvoToken
    const MockNuvoToken = await ethers.getContractFactory("MockNuvoToken");
    nuvoToken = await MockNuvoToken.deploy();
    await nuvoToken.deployed();

    // Deploy NuvoLockUpgradeable
    const NuvoLockUpgradeable = await ethers.getContractFactory("NuvoLockUpgradeable");
    nuvoLock = await upgrades.deployProxy(NuvoLockUpgradeable, [nuvoToken.address, owner.address, owner.address], { initializer: "initialize" });
    await nuvoLock.deployed();

    // Mint tokens and approve transfer
    await nuvoToken.mint(addr1.address, ethers.utils.parseUnits("1000", 18));
    await nuvoToken.connect(addr1).approve(nuvoLock.address, ethers.utils.parseUnits("1000", 18));

    await nuvoToken.mint(addr2.address, ethers.utils.parseUnits("1000", 18));
    await nuvoToken.connect(addr2).approve(nuvoLock.address, ethers.utils.parseUnits("1000", 18));

    // Lock tokens for addr1 and addr2
    await nuvoLock.connect(addr1).lock(ethers.utils.parseUnits("100", 18), 7 * 24 * 60 * 60); // 1 week
    await nuvoLock.connect(addr2).lock(ethers.utils.parseUnits("200", 18), 7 * 24 * 60 * 60); // 1 week
  });

  it("Should accumulate bonus points correctly for participants", async function () {
    await nuvoLock.accumulateBonusPoints(addr1.address);
    await nuvoLock.accumulateBonusPoints(addr2.address);

    const lockInfo1 = await nuvoLock.getLockInfo(addr1.address);
    const lockInfo2 = await nuvoLock.getLockInfo(addr2.address);

    expect(lockInfo1.bonusPoints).to.equal(1);
    expect(lockInfo2.bonusPoints).to.equal(1);
  });

  it("Should revert if non-owner tries to accumulate bonus points", async function () {
    await expect(nuvoLock.connect(addr1).accumulateBonusPoints(addr1.address))
      .to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("Should accumulate demerit points correctly for participants", async function () {
    await nuvoLock.accumulateDemeritPoints(addr1.address);
    await nuvoLock.accumulateDemeritPoints(addr2.address);

    const lockInfo1 = await nuvoLock.getLockInfo(addr1.address);
    const lockInfo2 = await nuvoLock.getLockInfo(addr2.address);

    expect(lockInfo1.demeritPoints).to.equal(1);
    expect(lockInfo2.demeritPoints).to.equal(1);
  });

  it("Should revert if non-owner tries to accumulate demerit points", async function () {
    await expect(nuvoLock.connect(addr1).accumulateDemeritPoints(addr1.address))
      .to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("Should correctly balance bonus and demerit points during reward accumulation", async function () {
    // Accumulate bonus and demerit points
    await nuvoLock.accumulateBonusPoints(addr1.address);
    await nuvoLock.accumulateDemeritPoints(addr1.address);

    // Set reward per period and accumulate rewards
    await nuvoLock.setRewardPerPeriod(ethers.utils.parseUnits("30", 18));
    await nuvoLock.accumulateRewards();

    const lockInfo = await nuvoLock.getLockInfo(addr1.address);
    const adjustedPoints = lockInfo.bonusPoints > lockInfo.demeritPoints ? lockInfo.bonusPoints - lockInfo.demeritPoints : 0;

    expect(adjustedPoints).to.equal(0); // Bonus points should be negated by demerit points
    expect(lockInfo.accumulatedRewards).to.equal(0); // No rewards should be accumulated due to negated points
  });

  it("Should carry over remaining demerit points to the next period", async function () {
    // Accumulate more demerit points than bonus points
    await nuvoLock.accumulateDemeritPoints(addr1.address);
    await nuvoLock.accumulateDemeritPoints(addr1.address);
    await nuvoLock.accumulateBonusPoints(addr1.address);

    // Set reward per period and accumulate rewards
    await nuvoLock.setRewardPerPeriod(ethers.utils.parseUnits("30", 18));
    await nuvoLock.accumulateRewards();

    const lockInfo = await nuvoLock.getLockInfo(addr1.address);
    expect(lockInfo.demeritPoints).to.equal(1); // One demerit point should carry over
    expect(lockInfo.accumulatedRewards).to.equal(0); // No rewards should be accumulated due to excess demerit points
  });
});
