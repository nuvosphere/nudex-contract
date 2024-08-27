const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Reward Voting", function () {
  let votingManager, participantManager, nuvoLock, owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();

    // Deploy mock contracts
    const MockParticipantManager = await ethers.getContractFactory("MockParticipantManager");
    participantManager = await MockParticipantManager.deploy();
    await participantManager.deployed();
    // Set addr1 participants
    await participantManager.mockSetParticipant(addr1.address, true);
    
    const MockNuvoLockUpgradeable = await ethers.getContractFactory("MockNuvoLockUpgradeable");
    nuvoLock = await MockNuvoLockUpgradeable.deploy();
    await nuvoLock.deployed();

    // Deploy VotingManager
    const VotingManager = await ethers.getContractFactory("VotingManager");
    votingManager = await upgrades.deployProxy(VotingManager, [participantManager.address, nuvoLock.address, ethers.constants.AddressZero, owner.address], { initializer: "initialize" });
    await votingManager.deployed();

    // Add addr1 as a participant
    await votingManager.addParticipant(addr1.address, "0x", "0x");
  });

  it("Should allow the current submitter to set reward per period", async function () {
    const newRewardPerPeriod = ethers.utils.parseUnits("10", 18);

    await expect(votingManager.setRewardPerPeriod(newRewardPerPeriod, "0x"))
      .to.emit(votingManager, "RewardPerPeriodVoted")
      .withArgs(newRewardPerPeriod);

    expect(await nuvoLock.rewardPerPeriod(0)).to.equal(newRewardPerPeriod);
  });

  it("Should revert if non-current submitter tries to set reward per period", async function () {
    const newRewardPerPeriod = ethers.utils.parseUnits("10", 18);

    await expect(votingManager.connect(addr1).setRewardPerPeriod(newRewardPerPeriod, "0x")).to.be.revertedWith("Not the current submitter");
  });

  it("Should revert if signature verification fails", async function () {
    const newRewardPerPeriod = ethers.utils.parseUnits("10", 18);

    await expect(votingManager.setRewardPerPeriod(newRewardPerPeriod, "0xInvalidSignature"))
      .to.be.revertedWith("Invalid signature");
  });
});
