const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NuvoLockUpgradeable - Reward Setting", function () {
  let nuvoLock, nuvoToken, rewardSource, owner, addr1;
  const lockAmount = ethers.parseUnits("100", 18);
  const lockPeriod = 7 * 24 * 60 * 60; // 1 week
  const rewardPerPeriod = ethers.parseUnits("10", 18);

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

    // Mint tokens to addr1 for testing
    await nuvoToken.mint(addr1.address, ethers.parseUnits("1000", 18));

    // Lock tokens for addr1
    await nuvoToken.connect(addr1).approve(await nuvoLock.getAddress(), lockAmount);
    await nuvoLock.connect(addr1).lock(lockAmount, lockPeriod);
  });

  it("Should allow owner to set reward per period", async function () {
    await expect(nuvoLock.connect(owner).setRewardPerPeriod(rewardPerPeriod))
      .to.emit(nuvoLock, "RewardPerPeriodUpdated")
      .withArgs(rewardPerPeriod, 0);

    expect(await nuvoLock.rewardPerPeriod(0)).to.equal(rewardPerPeriod);
  });

  it("Should accumulate rewards for previous periods before updating reward per period", async function () {
    // Simulate time passing to create a new period
    await ethers.provider.send("evm_increaseTime", [lockPeriod + 1]);
    await ethers.provider.send("evm_mine");

    // Set a reward for the new period
    const newRewardPerPeriod = ethers.parseUnits("20", 18);
    await nuvoLock.connect(owner).setRewardPerPeriod(newRewardPerPeriod);

    // Check that rewards for previous periods were correctly accumulated
    const lockInfo = await nuvoLock.getLockInfo(addr1.address);
    expect(lockInfo.accumulatedRewards).to.equal(rewardPerPeriod);
    expect(await nuvoLock.rewardPerPeriod(1)).to.equal(newRewardPerPeriod);
  });

  it("Should revert if non-owner tries to set reward per period", async function () {
    await expect(nuvoLock.connect(addr1).setRewardPerPeriod(rewardPerPeriod)).to.be.revertedWith(
      "Ownable: caller is not the owner"
    );
  });
});
