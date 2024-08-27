const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ParticipantManager - Removing Participants", function () {
  let participantManager, nuvoLock, owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

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
  });

  it("Should allow the owner to remove a participant", async function () {
    await expect(participantManager.removeParticipant(addr1.address))
      .to.emit(participantManager, "ParticipantRemoved")
      .withArgs(addr1.address);

    expect(await participantManager.isParticipant(addr1.address)).to.be.false;
  });

  it("Should revert if trying to remove a non-participant", async function () {
    await participantManager.removeParticipant(addr1.address); // Removing addr1 first
    await expect(participantManager.removeParticipant(addr1.address)).to.be.revertedWith("Not a participant");
  });

  it("Should correctly handle removing the last participant", async function () {
    await participantManager.removeParticipant(addr1.address);
    await participantManager.removeParticipant(addr2.address);

    expect(await participantManager.isParticipant(addr1.address)).to.be.false;
    expect(await participantManager.isParticipant(addr2.address)).to.be.false;

    const participants = await participantManager.getParticipants();
    expect(participants.length).to.equal(0);
  });
});
