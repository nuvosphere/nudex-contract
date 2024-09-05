const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Reward Voting", function () {
  let votingManager, participantManager, nuvoLock, owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    address1 = await addr1.getAddress();

    // Deploy mock contracts
    const MockParticipantManager = await ethers.getContractFactory("MockParticipantManager");
    participantManager = await MockParticipantManager.deploy();
    await participantManager.waitForDeployment();
    // Set addr1 participants
    await participantManager.mockSetParticipant(address1, true);

    const MockNuvoLockUpgradeable = await ethers.getContractFactory("MockNuvoLockUpgradeable");
    nuvoLock = await MockNuvoLockUpgradeable.deploy();
    await nuvoLock.waitForDeployment();

    // Deploy VotingManager
    const VotingManager = await ethers.getContractFactory("VotingManager");
    votingManager = await upgrades.deployProxy(
      VotingManager,
      [
        participantManager.address,
        await nuvoLock.getAddress(),
        ethers.ZeroAddress,
        await owner.getAddress(),
      ],
      { initializer: "initialize" }
    );
    await votingManager.waitForDeployment();

    // Add addr1 as a participant
    await votingManager.addParticipant(address1, "0x", "0x");
  });

  it("Should allow the current submitter to set reward per period", async function () {
    const newRewardPerPeriod = ethers.parseUnits("10", 18);

    await expect(votingManager.setRewardPerPeriod(newRewardPerPeriod, "0x"))
      .to.emit(votingManager, "RewardPerPeriodVoted")
      .withArgs(newRewardPerPeriod);

    expect(await nuvoLock.rewardPerPeriod(0)).to.equal(newRewardPerPeriod);
  });

  it("Should revert if non-current submitter tries to set reward per period", async function () {
    const newRewardPerPeriod = ethers.parseUnits("10", 18);

    await expect(
      votingManager.connect(addr1).setRewardPerPeriod(newRewardPerPeriod, "0x")
    ).to.be.revertedWith("Not the current submitter");
  });

  it("Should revert if signature verification fails", async function () {
    const newRewardPerPeriod = ethers.parseUnits("10", 18);

    await expect(
      votingManager.setRewardPerPeriod(newRewardPerPeriod, "0xInvalidSignature")
    ).to.be.revertedWith("Invalid signature");
  });
});
