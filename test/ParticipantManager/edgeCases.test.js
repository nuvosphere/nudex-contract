const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ParticipantManager - Edge Cases", function () {
  let participantManager, nuvoLock, owner, addr1, addr2, addr3;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

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
  });

  it("Should handle the scenario where no participants are added", async function () {
    const participants = await participantManager.getParticipants();
    expect(participants.length).to.equal(0);
  });

  it("Should revert if trying to remove a participant after all have been removed", async function () {
    await participantManager.addParticipant(addr1.address);
    await participantManager.removeParticipant(addr1.address);

    await expect(participantManager.removeParticipant(addr1.address)).to.be.revertedWith(
      "Not a participant"
    );
  });

  it("Should handle scenario where the same address is attempted to be added multiple times", async function () {
    await participantManager.addParticipant(addr1.address);
    await expect(participantManager.addParticipant(addr1.address)).to.be.revertedWith(
      "Already a participant"
    );
  });

  it("Should correctly reset isParticipant status after removing and re-adding the same participant", async function () {
    await participantManager.addParticipant(addr1.address);
    await participantManager.removeParticipant(addr1.address);

    expect(await participantManager.isParticipant(addr1.address)).to.be.false;

    await participantManager.addParticipant(addr1.address);

    expect(await participantManager.isParticipant(addr1.address)).to.be.true;
  });
});
