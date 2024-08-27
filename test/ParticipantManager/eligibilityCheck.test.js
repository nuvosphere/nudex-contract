const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ParticipantManager - Eligibility Check", function () {
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

  it("Should return true for eligible participant", async function () {
    const isEligible = await participantManager.isEligible(addr1.address);
    expect(isEligible).to.be.true;
  });

  it("Should return false for ineligible participant", async function () {
    // Override the mock to return a non-eligible lock info
    const MockNuvoLockUpgradeableIneligible = await ethers.getContractFactory("MockNuvoLockUpgradeableIneligible");
    nuvoLock = await MockNuvoLockUpgradeableIneligible.deploy();
    await nuvoLock.deployed();

    const ParticipantManager = await ethers.getContractFactory("ParticipantManager");
    participantManager = await upgrades.deployProxy(ParticipantManager, [nuvoLock.address, 100, 7 * 24 * 60 * 60, owner.address], { initializer: "initialize" });
    await participantManager.deployed();

    const isEligible = await participantManager.isEligible(addr2.address);
    expect(isEligible).to.be.false;
  });
});
