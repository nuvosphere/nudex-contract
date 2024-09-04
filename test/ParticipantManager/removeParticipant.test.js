const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ParticipantManager - Removing Participants", function () {
  let participantManager, nuvoLock, owner, addr1, addr2, address1, address2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    address1 = await addr1.getAddress();
    address2 = await addr2.getAddress();

    // Deploy mock NuvoLockUpgradeable
    const MockNuvoLockUpgradeable = await ethers.getContractFactory("MockNuvoLockUpgradeable");
    nuvoLock = await MockNuvoLockUpgradeable.deploy();
    await nuvoLock.waitForDeployment();

    // Deploy ParticipantManager
    const ParticipantManager = await ethers.getContractFactory("ParticipantManager");
    participantManager = await upgrades.deployProxy(
      ParticipantManager,
      [await nuvoLock.getAddress(), 100, 7 * 24 * 60 * 60, await owner.getAddress()],
      { initializer: "initialize" }
    );
    await participantManager.waitForDeployment();

    // Add participants
    await participantManager.addParticipant(address1);
    await participantManager.addParticipant(address2);
  });

  it("Should allow the owner to remove a participant", async function () {
    await expect(participantManager.removeParticipant(address1))
      .to.emit(participantManager, "ParticipantRemoved")
      .withArgs(address1);

    expect(await participantManager.isParticipant(address1)).to.be.false;
  });

  it("Should revert if trying to remove a non-participant", async function () {
    await participantManager.removeParticipant(address1); // Removing addr1 first
    await expect(participantManager.removeParticipant(address1)).to.be.revertedWith(
      "Not a participant"
    );
  });

  it("Should correctly handle removing the last participant", async function () {
    await participantManager.removeParticipant(address1);
    await participantManager.removeParticipant(address2);

    expect(await participantManager.isParticipant(address1)).to.be.false;
    expect(await participantManager.isParticipant(address2)).to.be.false;

    const participants = await participantManager.getParticipants();
    expect(participants.length).to.equal(0);
  });
});
