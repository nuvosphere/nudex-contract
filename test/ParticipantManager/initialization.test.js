const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ParticipantManager - Initialization", function () {
  let participantManager, nuvoLock, owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    address1 = await addr1.getAddress();

    // Deploy mock NuvoLockUpgradeable
    const NuvoLockUpgradeable = await ethers.getContractFactory("MockNuvoLockUpgradeablePreset");
    nuvoLock = await NuvoLockUpgradeable.deploy();
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

  it("Should initialize with correct parameters", async function () {
    expect(await participantManager.nuvoLock()).to.equal(await nuvoLock.getAddress());
    expect(await participantManager.minLockAmount()).to.equal(100);
    expect(await participantManager.minLockPeriod()).to.equal(7 * 24 * 60 * 60);
    expect(await participantManager.owner()).to.equal(await owner.getAddress());
  });
});
