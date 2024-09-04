const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NuvoLockUpgradeable - Reward Distribution", function () {
  let nuvoLock, nuvoToken, rewardSource, owner, addr1, addr2, address1, address2;
  const lockAmount = ethers.parseUnits("100", 18);
  const lockPeriod = 7 * 24 * 60 * 60; // 1 week
  const rewardPerPeriod = ethers.parseUnits("10", 18);

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

    // Mint tokens to addr1 and rewardSource for testing
    await nuvoToken.mint(address1, ethers.parseUnits("1000", 18));
    await nuvoToken.mint(address2, ethers.parseUnits("1000", 18));
    await nuvoToken.mint(await rewardSource.getAddress(), ethers.parseUnits("1000", 18));
    await nuvoToken
      .connect(rewardSource)
      .approve(await nuvoLock.getAddress(), ethers.parseUnits("1000", 18));

    // Lock tokens for addr1 and addr2
    await nuvoToken.connect(addr1).approve(await nuvoLock.getAddress(), lockAmount);
    await nuvoLock.connect(addr1).lock(lockAmount, lockPeriod);
    await nuvoToken.connect(addr2).approve(await nuvoLock.getAddress(), lockAmount);
    await nuvoLock.connect(addr2).lock(lockAmount, lockPeriod);

    // Set reward per period
    await nuvoLock.connect(owner).setRewardPerPeriod(rewardPerPeriod);
  });

  it("Should accumulate rewards over multiple periods", async function () {
    // Simulate passing of time
    await ethers.provider.send("evm_increaseTime", [lockPeriod + 1]);
    await ethers.provider.send("evm_mine");

    await nuvoLock.connect(owner).accumulateBonusPoints(address1);
    await nuvoLock.connect(owner).accumulateBonusPoints(address2);

    // Set reward per period
    await nuvoLock.connect(owner).setRewardPerPeriod(rewardPerPeriod);

    // Simulate another period
    await ethers.provider.send("evm_increaseTime", [lockPeriod + 1]);
    await ethers.provider.send("evm_mine");

    await nuvoLock.connect(owner).accumulateBonusPoints(address1);
    await nuvoLock.connect(owner).accumulateBonusPoints(address2);

    const lockInfo1 = await nuvoLock.getLockInfo(address1);
    const lockInfo2 = await nuvoLock.getLockInfo(address2);

    expect(lockInfo1.accumulatedRewards).to.equal((rewardPerPeriod / 2n) * 2n); // Half the reward, two periods
    expect(lockInfo2.accumulatedRewards).to.equal((rewardPerPeriod / 2n) * 2n); // Half the reward, two periods
  });

  it("Should allow claiming rewards", async function () {
    // Simulate passing of time and accumulate rewards
    await ethers.provider.send("evm_increaseTime", [lockPeriod + 1]);
    await ethers.provider.send("evm_mine");

    await nuvoLock.connect(owner).accumulateBonusPoints(address1);
    await nuvoLock.accumulateRewards();

    // Claim rewards
    await expect(nuvoLock.connect(addr1).claimRewards())
      .to.emit(nuvoLock, "RewardsClaimed")
      .withArgs(address1, rewardPerPeriod); // FIXME: rewardPerPeriod was divided by 2?

    const lockInfo1 = await nuvoLock.getLockInfo(address1);
    expect(lockInfo1.accumulatedRewards).to.equal(0);
  });

  it("Should revert when claiming rewards with no accumulated rewards", async function () {
    await expect(nuvoLock.connect(addr2).claimRewards()).to.be.revertedWith("No rewards to claim");
  });
});
