const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ParticipantManager - Eligibility Check", function () {
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
  });

  it("Should return true for eligible participant", async function () {
    const isEligible = await participantManager.isEligible(address1);
    expect(isEligible).to.be.true;
  });

  it("Should return false for ineligible participant", async function () {
    // Override the mock to return a non-eligible lock info
    const MockNuvoLockUpgradeableIneligible = await ethers.getContractFactory(
      "MockNuvoLockUpgradeableIneligible"
    );
    nuvoLock = await MockNuvoLockUpgradeableIneligible.deploy();
    await nuvoLock.waitForDeployment();

    const ParticipantManager = await ethers.getContractFactory("ParticipantManager");
    participantManager = await upgrades.deployProxy(
      ParticipantManager,
      [await nuvoLock.getAddress(), 100, 7 * 24 * 60 * 60, await owner.getAddress()],
      { initializer: "initialize" }
    );
    await participantManager.waitForDeployment();

    const isEligible = await participantManager.isEligible(address2);
    expect(isEligible).to.be.false;
  });
});
