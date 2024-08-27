const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NuvoLockUpgradeable - Edge Cases", function () {
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
  });

  it("Should revert if trying to claim rewards with zero accumulated rewards", async function () {
    await expect(nuvoLock.connect(addr1).claimRewards()).to.be.revertedWith("No rewards to claim");
  });

  it("Should handle reward calculation correctly when no bonus points are present", async function () {
    await nuvoToken.connect(addr1).approve(nuvoLock.address, lockAmount);
    await nuvoLock.connect(addr1).lock(lockAmount, lockPeriod);

    // Set reward per period
    const rewardPerPeriod = ethers.utils.parseUnits("10", 18);
    await nuvoLock.connect(owner).setRewardPerPeriod(rewardPerPeriod);

    // Simulate time passing to create a new period
    await ethers.provider.send("evm_increaseTime", [lockPeriod + 1]);
    await ethers.provider.send("evm_mine");

    // Accumulate rewards
    await nuvoLock.connect(owner).accumulateRewards();

    const lockInfo = await nuvoLock.getLockInfo(addr1.address);
    expect(lockInfo.accumulatedRewards).to.equal(0);
  });

  it("Should correctly iterate through multiple participants", async function () {
    await nuvoToken.connect(addr1).approve(nuvoLock.address, lockAmount);
    await nuvoLock.connect(addr1).lock(lockAmount, lockPeriod);

    await nuvoToken.connect(addr2).approve(nuvoLock.address, lockAmount);
    await nuvoLock.connect(addr2).lock(lockAmount, lockPeriod);

    // Set reward per period
    const rewardPerPeriod = ethers.utils.parseUnits("20", 18);
    await nuvoLock.connect(owner).setRewardPerPeriod(rewardPerPeriod);

    // Simulate time passing to create a new period
    await ethers.provider.send("evm_increaseTime", [lockPeriod + 1]);
    await ethers.provider.send("evm_mine");

    // Accumulate rewards
    await nuvoLock.connect(owner).accumulateRewards();

    const lockInfo1 = await nuvoLock.getLockInfo(addr1.address);
    const lockInfo2 = await nuvoLock.getLockInfo(addr2.address);

    expect(lockInfo1.accumulatedRewards).to.equal(rewardPerPeriod.div(2));
    expect(lockInfo2.accumulatedRewards).to.equal(rewardPerPeriod.div(2));
  });

  it("Should handle multiple reward periods correctly", async function () {
    await nuvoToken.connect(addr1).approve(nuvoLock.address, lockAmount);
    await nuvoLock.connect(addr1).lock(lockAmount, lockPeriod);

    // Set reward per period
    const rewardPerPeriod = ethers.utils.parseUnits("10", 18);
    await nuvoLock.connect(owner).setRewardPerPeriod(rewardPerPeriod);

    // Simulate multiple periods passing
    await ethers.provider.send("evm_increaseTime", [lockPeriod * 2 + 1]);
    await ethers.provider.send("evm_mine");

    // Accumulate rewards
    await nuvoLock.connect(owner).accumulateRewards();

    const lockInfo = await nuvoLock.getLockInfo(addr1.address);
    expect(lockInfo.accumulatedRewards).to.equal(rewardPerPeriod);
  });

  it("Should handle multiple reward periods with zero total bonus points", async function () {
    await nuvoToken.connect(addr1).approve(nuvoLock.address, lockAmount);
    await nuvoLock.connect(addr1).lock(lockAmount, lockPeriod);

    // Set reward per period
    const rewardPerPeriod = ethers.utils.parseUnits("10", 18);
    await nuvoLock.connect(owner).setRewardPerPeriod(rewardPerPeriod);

    // Simulate passing through multiple periods with zero bonus points
    await ethers.provider.send("evm_increaseTime", [lockPeriod * 3 + 1]);
    await ethers.provider.send("evm_mine");

    // Accumulate rewards
    await nuvoLock.connect(owner).accumulateRewards();

    const lockInfo = await nuvoLock.getLockInfo(addr1.address);
    expect(lockInfo.accumulatedRewards).to.equal(0); // No rewards should accumulate
  });

  it("Should handle initial period with bonus points followed by multiple zero-bonus periods", async function () {
    await nuvoToken.connect(addr1).approve(nuvoLock.address, lockAmount);
    await nuvoLock.connect(addr1).lock(lockAmount, lockPeriod);

    // Set reward per period
    const rewardPerPeriod = ethers.utils.parseUnits("10", 18);
    await nuvoLock.connect(owner).setRewardPerPeriod(rewardPerPeriod);

    // Accumulate bonus points in the first period
    await nuvoLock.connect(owner).accumulateBonusPoints(addr1.address);

    // Simulate one period passing
    await ethers.provider.send("evm_increaseTime", [lockPeriod + 1]);
    await ethers.provider.send("evm_mine");

    // Accumulate rewards for the first period
    await nuvoLock.connect(owner).accumulateRewards();

    let lockInfo = await nuvoLock.getLockInfo(addr1.address);
    expect(lockInfo.accumulatedRewards).to.equal(rewardPerPeriod);

    // Simulate passing through subsequent periods with zero bonus points
    await ethers.provider.send("evm_increaseTime", [lockPeriod * 2 + 1]);
    await ethers.provider.send("evm_mine");

    // Accumulate rewards for the subsequent periods
    await nuvoLock.connect(owner).accumulateRewards();

    lockInfo = await nuvoLock.getLockInfo(addr1.address);
    expect(lockInfo.accumulatedRewards).to.equal(rewardPerPeriod); // Rewards should remain the same as no new rewards should accumulate
  });
});
