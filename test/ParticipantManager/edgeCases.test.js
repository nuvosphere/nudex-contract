const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ParticipantManager - Edge Cases", function () {
  let participantManager, nuvoLock, owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    address1 = await addr1.getAddress();

    // Deploy mock NuvoLockUpgradeable
    const MockNuvoLockUpgradeable = await ethers.getContractFactory(
      "MockNuvoLockUpgradeablePreset"
    );
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
    await participantManager.addParticipant(address1);
    await participantManager.removeParticipant(address1);

    await expect(participantManager.removeParticipant(address1)).to.be.revertedWith(
      "Not a participant"
    );
  });

  it("Should handle scenario where the same address is attempted to be added multiple times", async function () {
    await participantManager.addParticipant(address1);
    await expect(participantManager.addParticipant(address1)).to.be.revertedWith(
      "Already a participant"
    );
  });

  it("Should correctly reset isParticipant status after removing and re-adding the same participant", async function () {
    await participantManager.addParticipant(address1);
    await participantManager.removeParticipant(address1);

    expect(await participantManager.isParticipant(address1)).to.be.false;

    await participantManager.addParticipant(address1);

    expect(await participantManager.isParticipant(address1)).to.be.true;
  });
});
