const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ParticipantManager - Fetching Participants", function () {
  let participantManager, nuvoLock, owner, addr1, addr2, addr3;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    // Deploy mock NuvoLockUpgradeable
    const MockNuvoLockUpgradeable = await ethers.getContractFactory("MockNuvoLockUpgradeable");
    nuvoLock = await MockNuvoLockUpgradeable.deploy();
    await nuvoLock.deployed();

    // Deploy ParticipantManager
    const ParticipantManager = await ethers.getContractFactory("ParticipantManager");
    participantManager = await upgrades.deployProxy(ParticipantManager, [nuvoLock.address, 100, 7 * 24 * 60 * 60, owner.address], { initializer: "initialize" });
    await participantManager.deployed();

    // Add participants
    await participantManager.addParticipant(addr1.address);
    await participantManager.addParticipant(addr2.address);
    await participantManager.addParticipant(addr3.address);
  });

  it("Should return the correct list of participants", async function () {
    const participants = await participantManager.getParticipants();
    expect(participants.length).to.equal(3);
    expect(participants).to.include.members([addr1.address, addr2.address, addr3.address]);
  });

  it("Should return an empty list when no participants are present", async function () {
    // Remove all participants
    await participantManager.removeParticipant(addr1.address);
    await participantManager.removeParticipant(addr2.address);
    await participantManager.removeParticipant(addr3.address);

    const participants = await participantManager.getParticipants();
    expect(participants.length).to.equal(0);
  });
});
