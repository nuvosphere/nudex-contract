const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Initialization", function () {
  let votingManager, participantManager, nuvoLock, depositManager, owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();

    // Deploy mock contracts
    const MockParticipantManager = await ethers.getContractFactory("MockParticipantManager");
    participantManager = await MockParticipantManager.deploy();
    await participantManager.deployed();
    // Set addr1 participants
    await participantManager.mockSetParticipant(addr1.address, true);
    
    const MockNuvoLockUpgradeable = await ethers.getContractFactory("MockNuvoLockUpgradeable");
    nuvoLock = await MockNuvoLockUpgradeable.deploy();
    await nuvoLock.deployed();

    const MockDepositManager = await ethers.getContractFactory("MockDepositManager");
    depositManager = await MockDepositManager.deploy();
    await depositManager.deployed();

    // Deploy VotingManager
    const VotingManager = await ethers.getContractFactory("VotingManager");
    votingManager = await upgrades.deployProxy(VotingManager, [participantManager.address, nuvoLock.address, depositManager.address, owner.address], { initializer: "initialize" });
    await votingManager.deployed();
  });

  it("Should initialize with correct parameters", async function () {
    expect(await votingManager.participantManager()).to.equal(participantManager.address);
    expect(await votingManager.nuvoLock()).to.equal(nuvoLock.address);
    expect(await votingManager.depositManager()).to.equal(depositManager.address);
    expect(await votingManager.owner()).to.equal(owner.address);
  });

  it("Should only allow owner to initialize", async function () {
    const VotingManager = await ethers.getContractFactory("VotingManager");
    await expect(
      upgrades.deployProxy(VotingManager, [participantManager.address, nuvoLock.address, depositManager.address, addr1.address], { initializer: "initialize" })
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });
});
