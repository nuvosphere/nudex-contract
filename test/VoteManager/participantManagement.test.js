const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Participant Management", function () {
  let votingManager, participantManager, nuvoLock, owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    // Deploy mock contracts
    const MockParticipantManager = await ethers.getContractFactory("MockParticipantManager");
    participantManager = await MockParticipantManager.deploy();
    await participantManager.waitForDeployment();

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
        ethers.constants.AddressZero,
        await owner.getAddress(),
      ],
      { initializer: "initialize" }
    );
    await votingManager.waitForDeployment();
  });

  it("Should allow the current submitter to add a new participant", async function () {
    // Simulate adding a new participant
    await votingManager.addParticipant(addr1.address, "0x", "0x");

    expect(await participantManager.isParticipant(addr1.address)).to.be.true;
  });

  it("Should revert if non-current submitter tries to add a participant", async function () {
    // Trying to add a participant from a non-current submitter
    await expect(
      votingManager.connect(addr2).addParticipant(addr1.address, "0x", "0x")
    ).to.be.revertedWith("Not the current submitter");
  });

  it("Should allow the current submitter to remove a participant", async function () {
    // Simulate adding and then removing a participant
    await votingManager.addParticipant(addr1.address, "0x", "0x");
    await votingManager.removeParticipant(addr1.address, "0x", "0x");

    expect(await participantManager.isParticipant(addr1.address)).to.be.false;
  });

  it("Should revert if non-current submitter tries to remove a participant", async function () {
    // Simulate adding a participant
    await votingManager.addParticipant(addr1.address, "0x", "0x");

    // Trying to remove the participant from a non-current submitter
    await expect(
      votingManager.connect(addr2).removeParticipant(addr1.address, "0x", "0x")
    ).to.be.revertedWith("Not the current submitter");
  });
});
