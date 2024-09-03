const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NuvoLockUpgradeable - Reward Accumulation and Claiming", function () {
  let nuvoLock, nuvoToken, rewardSource, owner, addr1, addr2;

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

    // Mint tokens and approve transfer
    await nuvoToken.mint(addr1.address, ethers.parseUnits("1000", 18));
    await nuvoToken
      .connect(addr1)
      .approve(await nuvoLock.getAddress(), ethers.parseUnits("1000", 18));

    await nuvoToken.mint(addr2.address, ethers.parseUnits("1000", 18));
    await nuvoToken
      .connect(addr2)
      .approve(await nuvoLock.getAddress(), ethers.parseUnits("1000", 18));
  });

  it("Should accumulate rewards correctly for multiple participants", async function () {
    // Lock tokens for addr1 and addr2
    await nuvoLock.connect(addr1).lock(ethers.parseUnits("100", 18), 7 * 24 * 60 * 60); // 1 week
    await nuvoLock.connect(addr2).lock(ethers.parseUnits("200", 18), 7 * 24 * 60 * 60); // 1 week

    // Set reward per period
    await nuvoLock.setRewardPerPeriod(ethers.parseUnits("30", 18));

    // Accumulate bonus points
    await nuvoLock.accumulateBonusPoints(addr1.address);
    await nuvoLock.accumulateBonusPoints(addr2.address);

    // Accumulate rewards
    await nuvoLock.accumulateRewards();

    const lockInfo1 = await nuvoLock.getLockInfo(addr1.address);
    const lockInfo2 = await nuvoLock.getLockInfo(addr2.address);

    expect(lockInfo1.accumulatedRewards).to.be.gt(0);
    expect(lockInfo2.accumulatedRewards).to.be.gt(0);
  });

  it("Should revert reward claim if no rewards are available", async function () {
    await expect(nuvoLock.connect(addr1).claimRewards()).to.be.revertedWith("No rewards to claim");
  });

  it("Should allow claiming of accumulated rewards", async function () {
    // Lock tokens for addr1
    await nuvoLock.connect(addr1).lock(ethers.parseUnits("100", 18), 7 * 24 * 60 * 60); // 1 week

    // Set reward per period
    await nuvoLock.setRewardPerPeriod(ethers.parseUnits("30", 18));

    // Accumulate bonus points and rewards
    await nuvoLock.accumulateBonusPoints(addr1.address);
    await nuvoLock.accumulateRewards();

    // Claim rewards
    const initialBalance = await nuvoToken.balanceOf(addr1.address);
    await nuvoLock.connect(addr1).claimRewards();
    const finalBalance = await nuvoToken.balanceOf(addr1.address);

    expect(finalBalance).to.be.gt(initialBalance);
  });

  it("Should correctly handle multiple reward periods with zero total bonus", async function () {
    // Lock tokens for addr1
    await nuvoLock.connect(addr1).lock(ethers.parseUnits("100", 18), 7 * 24 * 60 * 60); // 1 week

    // Set reward per period
    await nuvoLock.setRewardPerPeriod(ethers.parseUnits("30", 18));

    // Simulate time passing for multiple periods
    await ethers.provider.send("evm_increaseTime", [14 * 24 * 60 * 60]); // 2 weeks
    await ethers.provider.send("evm_mine");

    // Accumulate rewards
    await nuvoLock.accumulateRewards();

    const lockInfo = await nuvoLock.getLockInfo(addr1.address);
    expect(lockInfo.accumulatedRewards).to.equal(0);
  });

  it("Should handle the first reward period with points followed by zero points periods", async function () {
    // Lock tokens for addr1
    await nuvoLock.connect(addr1).lock(ethers.parseUnits("100", 18), 7 * 24 * 60 * 60); // 1 week

    // Set reward per period
    await nuvoLock.setRewardPerPeriod(ethers.parseUnits("30", 18));

    // Accumulate bonus points for the first period
    await nuvoLock.accumulateBonusPoints(addr1.address);

    // Accumulate rewards for the first period
    await nuvoLock.accumulateRewards();

    // Simulate time passing for the next period with zero points
    await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60]); // 1 week
    await ethers.provider.send("evm_mine");

    // Set reward per period for the next period with zero points
    await nuvoLock.setRewardPerPeriod(ethers.parseUnits("30", 18));
    await nuvoLock.accumulateRewards();

    const lockInfo = await nuvoLock.getLockInfo(addr1.address);
    expect(lockInfo.accumulatedRewards).to.be.gt(0);
  });
});
