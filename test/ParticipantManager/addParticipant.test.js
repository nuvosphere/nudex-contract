const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ParticipantManager - Adding Participants", function () {
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
  });

  it("Should allow the owner to add a new participant if eligible", async function () {
    await expect(participantManager.addParticipant(addr1.address))
      .to.emit(participantManager, "ParticipantAdded")
      .withArgs(addr1.address);

    expect(await participantManager.isParticipant(addr1.address)).to.be.true;
  });

  it("Should revert if trying to add a participant that is already a participant", async function () {
    await participantManager.addParticipant(addr1.address);
    await expect(participantManager.addParticipant(addr1.address)).to.be.revertedWith("Already a participant");
  });

  it("Should revert if trying to add a participant that is not eligible", async function () {
    // Override the mock to return a non-eligible lock info
    const MockNuvoLockUpgradeableIneligible = await ethers.getContractFactory("MockNuvoLockUpgradeableIneligible");
    nuvoLock = await MockNuvoLockUpgradeableIneligible.deploy();
    await nuvoLock.deployed();

    const ParticipantManager = await ethers.getContractFactory("ParticipantManager");
    participantManager = await upgrades.deployProxy(ParticipantManager, [nuvoLock.address, 100, 7 * 24 * 60 * 60, owner.address], { initializer: "initialize" });
    await participantManager.deployed();

    await expect(participantManager.addParticipant(addr2.address)).to.be.revertedWith("Participant not eligible");
  });
});
