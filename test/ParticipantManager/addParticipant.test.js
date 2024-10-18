const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ParticipantManager - Adding Participants", function () {
  let participantManager, nuvoLock, owner, addr1, addr2, ownerAddress, address1, address2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    ownerAddress = await owner.getAddress();
    address1 = await addr1.getAddress();
    address2 = await addr2.getAddress();

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
      [await nuvoLock.getAddress(), 100, 7 * 24 * 60 * 60, ownerAddress, ownerAddress],
      { initializer: "initialize" }
    );
    await participantManager.waitForDeployment();
  });

  it("Should allow the owner to add a new participant if eligible", async function () {
    await expect(participantManager.addParticipant(address1))
      .to.emit(participantManager, "ParticipantAdded")
      .withArgs(address1);

    expect(await participantManager.isParticipant(address1)).to.be.true;
  });

  it("Should revert if trying to add a participant that is already a participant", async function () {
    await participantManager.addParticipant(address1);
    await expect(participantManager.addParticipant(address1)).to.be.revertedWith(
      "Already a participant"
    );
  });

  it("Should revert if trying to add a participant that is not eligible", async function () {
    // Override the mock to return a non-eligible lock info
    const MockNuvoLockUpgradeablePreset = await ethers.getContractFactory(
      "MockNuvoLockUpgradeablePreset"
    );
    nuvoLock = await MockNuvoLockUpgradeablePreset.deploy();
    await nuvoLock.waitForDeployment();

    const ParticipantManager = await ethers.getContractFactory("ParticipantManager");
    participantManager = await upgrades.deployProxy(
      ParticipantManager,
      [await nuvoLock.getAddress(), 200, 7 * 24 * 60 * 60, ownerAddress, ownerAddress],
      { initializer: "initialize" }
    );
    await participantManager.waitForDeployment();

    await expect(participantManager.addParticipant(address2)).to.be.revertedWith(
      "Participant not eligible"
    );
  });
});
