const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Initialization", function () {
  let votingManager, participantManager, nuvoLock, depositManager, owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    address1 = await addr1.getAddress();

    // Deploy mock contracts
    const MockParticipantManager = await ethers.getContractFactory("MockParticipantManager");
    participantManager = await MockParticipantManager.deploy();
    await participantManager.waitForDeployment();
    // Set addr1 participants
    await participantManager.addParticipant(address1);

    const MockNuvoLockUpgradeable = await ethers.getContractFactory("MockNuvoLockUpgradeable");
    nuvoLock = await MockNuvoLockUpgradeable.deploy();
    await nuvoLock.waitForDeployment();

    const MockDepositManager = await ethers.getContractFactory("MockDepositManager");
    depositManager = await MockDepositManager.deploy();
    await depositManager.waitForDeployment();

    // Deploy VotingManager
    const VotingManager = await ethers.getContractFactory("VotingManager");
    votingManager = await upgrades.deployProxy(
      VotingManager,
      [
        ethers.ZeroAddress, // account manager
        ethers.ZeroAddress, // asset manager
        await depositManager.getAddress(), // deposit manager
        await participantManager.getAddress(), // participant manager
        ethers.ZeroAddress, // nuDex operation
        await nuvoLock.getAddress(), // nuvoLock
        await owner.getAddress(), // owner
      ],
      { initializer: "initialize" }
    );
    await votingManager.waitForDeployment();
  });

  it("Should initialize with correct parameters", async function () {
    expect(await votingManager.participantManager()).to.equal(
      await participantManager.getAddress()
    );
    expect(await votingManager.nuvoLock()).to.equal(await nuvoLock.getAddress());
    expect(await votingManager.depositManager()).to.equal(await depositManager.getAddress());
    expect(await votingManager.owner()).to.equal(await owner.getAddress());
  });
});
