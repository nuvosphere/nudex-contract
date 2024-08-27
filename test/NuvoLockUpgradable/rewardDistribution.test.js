const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NuvoLockUpgradeable - Reward Distribution", function () {
  let nuvoLock, nuvoToken, rewardSource, owner, addr1, addr2;
  const lockAmount = ethers.utils.parseUnits("100", 18);
  const lockPeriod = 7 * 24 * 60 * 60; // 1 week
  const rewardPerPeriod = ethers.utils.parseUnits("10", 18);

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

    // Mint tokens to addr1 and rewardSource for testing
    await nuvoToken.mint(addr1.address, ethers.utils.parseUnits("1000", 18));
    await nuvoToken.mint(rewardSource.address, ethers.utils.parseUnits("1000", 18));

    // Lock tokens for addr1 and addr2
    await nuvoToken.connect(addr1).approve(nuvoLock.address, lockAmount);
    await nuvoLock.connect(addr1).lock(lockAmount, lockPeriod);
    await nuvoToken.connect(addr2).approve(nuvoLock.address, lockAmount);
    await nuvoLock.connect(addr2).lock(lockAmount, lockPeriod);

    // Set reward per period
    await nuvoLock.connect(owner).setRewardPerPeriod(rewardPerPeriod);
  });

  it("Should accumulate rewards over multiple periods", async function () {
    // Simulate passing of time
    await ethers.provider.send("evm_increaseTime", [lockPeriod + 1]);
    await ethers.provider.send("evm_mine");

    await nuvoLock.connect(owner).accumulateBonusPoints(addr1.address);
    await nuvoLock.connect(owner).accumulateBonusPoints(addr2.address);

    // Simulate another period
    await ethers.provider.send("evm_increaseTime", [lockPeriod + 1]);
    await ethers.provider.send("evm_mine");

    await nuvoLock.connect(owner).accumulateBonusPoints(addr1.address);
    await nuvoLock.connect(owner).accumulateBonusPoints(addr2.address);

    const lockInfo1 = await nuvoLock.getLockInfo(addr1.address);
    const lockInfo2 = await nuvoLock.getLockInfo(addr2.address);

    expect(lockInfo1.accumulatedRewards).to.equal(rewardPerPeriod.div(2).mul(2)); // Half the reward, two periods
    expect(lockInfo2.accumulatedRewards).to.equal(rewardPerPeriod.div(2).mul(2)); // Half the reward, two periods
  });

  it("Should allow claiming rewards", async function () {
    // Simulate passing of time and accumulate rewards
    await ethers.provider.send("evm_increaseTime", [lockPeriod + 1]);
    await ethers.provider.send("evm_mine");

    await nuvoLock.connect(owner).accumulateBonusPoints(addr1.address);

    // Claim rewards
    await expect(nuvoLock.connect(addr1).claimRewards())
      .to.emit(nuvoLock, "RewardsClaimed")
      .withArgs(addr1.address, rewardPerPeriod.div(2));

    const lockInfo1 = await nuvoLock.getLockInfo(addr1.address);
    expect(lockInfo1.accumulatedRewards).to.equal(0);
  });

  it("Should revert when claiming rewards with no accumulated rewards", async function () {
    await expect(nuvoLock.connect(addr2).claimRewards()).to.be.revertedWith("No rewards to claim");
  });
});
