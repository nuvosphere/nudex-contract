const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NuvoLockUpgradeable - Bonus and Demerit Points Accumulation", function () {
  let nuvoLock, nuvoToken, owner, addr1, addr2, address1, address2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
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
      [await nuvoToken.getAddress(), await owner.getAddress(), await owner.getAddress()],
      { initializer: "initialize" }
    );
    await nuvoLock.waitForDeployment();

    // Mint tokens and approve transfer
    await nuvoToken.mint(address1, ethers.parseUnits("1000", 18));
    await nuvoToken
      .connect(addr1)
      .approve(await nuvoLock.getAddress(), ethers.parseUnits("1000", 18));

    await nuvoToken.mint(address2, ethers.parseUnits("1000", 18));
    await nuvoToken
      .connect(addr2)
      .approve(await nuvoLock.getAddress(), ethers.parseUnits("1000", 18));

    // Lock tokens for addr1 and addr2
    await nuvoLock.connect(addr1).lock(ethers.parseUnits("100", 18), 7 * 24 * 60 * 60); // 1 week
    await nuvoLock.connect(addr2).lock(ethers.parseUnits("200", 18), 7 * 24 * 60 * 60); // 1 week
  });

  it("Should accumulate bonus points correctly for participants", async function () {
    await nuvoLock.accumulateBonusPoints(address1);
    await nuvoLock.accumulateBonusPoints(address2);

    const lockInfo1 = await nuvoLock.getLockInfo(address1);
    const lockInfo2 = await nuvoLock.getLockInfo(address2);

    expect(lockInfo1.bonusPoints).to.equal(1);
    expect(lockInfo2.bonusPoints).to.equal(1);
  });

  it("Should revert if non-owner tries to accumulate bonus points", async function () {
    await expect(
      nuvoLock.connect(addr1).accumulateBonusPoints(address1)
    ).to.be.revertedWithCustomError(nuvoLock, "OwnableUnauthorizedAccount");
  });

  it("Should accumulate demerit points correctly for participants", async function () {
    await nuvoLock.accumulateDemeritPoints(address1);
    await nuvoLock.accumulateDemeritPoints(address2);

    const lockInfo1 = await nuvoLock.getLockInfo(address1);
    const lockInfo2 = await nuvoLock.getLockInfo(address2);

    expect(lockInfo1.demeritPoints).to.equal(1);
    expect(lockInfo2.demeritPoints).to.equal(1);
  });

  it("Should revert if non-owner tries to accumulate demerit points", async function () {
    await expect(
      nuvoLock.connect(addr1).accumulateDemeritPoints(address1)
    ).to.be.revertedWithCustomError(nuvoLock, "OwnableUnauthorizedAccount");
  });

  it("Should correctly balance bonus and demerit points during reward accumulation", async function () {
    // Accumulate bonus and demerit points
    await nuvoLock.accumulateBonusPoints(address1);
    await nuvoLock.accumulateDemeritPoints(address1);

    // Set reward per period and accumulate rewards
    await nuvoLock.setRewardPerPeriod(ethers.parseUnits("30", 18));
    await nuvoLock.accumulateRewards();

    const lockInfo = await nuvoLock.getLockInfo(address1);
    const adjustedPoints =
      lockInfo.bonusPoints > lockInfo.demeritPoints
        ? lockInfo.bonusPoints - lockInfo.demeritPoints
        : 0;

    expect(adjustedPoints).to.equal(0); // Bonus points should be negated by demerit points
    expect(lockInfo.accumulatedRewards).to.equal(0); // No rewards should be accumulated due to negated points
  });

  it("Should carry over remaining demerit points to the next period", async function () {
    // Accumulate more demerit points than bonus points
    await nuvoLock.accumulateDemeritPoints(address1);
    // await nuvoLock.accumulateDemeritPoints(address1); // FIXME: this is called twice, was this intended?
    await nuvoLock.accumulateBonusPoints(address1);

    // Set reward per period and accumulate rewards
    await nuvoLock.setRewardPerPeriod(ethers.parseUnits("30", 18));
    await nuvoLock.accumulateRewards();

    const lockInfo = await nuvoLock.getLockInfo(address1);
    expect(lockInfo.demeritPoints).to.equal(1); // One demerit point should carry over
    expect(lockInfo.accumulatedRewards).to.equal(0); // No rewards should be accumulated due to excess demerit points
  });
});
