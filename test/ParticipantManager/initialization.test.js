const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ParticipantManager - Initialization", function () {
  let participantManager, nuvoLock, owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();

    // Deploy mock NuvoLockUpgradeable
    const NuvoLockUpgradeable = await ethers.getContractFactory("MockNuvoLockUpgradeable");
    nuvoLock = await NuvoLockUpgradeable.deploy();
    await nuvoLock.deployed();

    // Deploy ParticipantManager
    const ParticipantManager = await ethers.getContractFactory("ParticipantManager");
    participantManager = await upgrades.deployProxy(ParticipantManager, [nuvoLock.address, 100, 7 * 24 * 60 * 60, owner.address], { initializer: "initialize" });
    await participantManager.deployed();
  });

  it("Should initialize with correct parameters", async function () {
    expect(await participantManager.nuvoLock()).to.equal(nuvoLock.address);
    expect(await participantManager.minLockAmount()).to.equal(100);
    expect(await participantManager.minLockPeriod()).to.equal(7 * 24 * 60 * 60);
    expect(await participantManager.owner()).to.equal(owner.address);
  });

  it("Should only allow owner to initialize", async function () {
    const ParticipantManager = await ethers.getContractFactory("ParticipantManager");
    await expect(
      upgrades.deployProxy(ParticipantManager, [nuvoLock.address, 100, 7 * 24 * 60 * 60, addr1.address], { initializer: "initialize" })
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });
});
