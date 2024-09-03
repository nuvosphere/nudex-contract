const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Initialization", function () {
  let votingManager, participantManager, nuvoLock, depositManager, owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();

    // Deploy mock contracts
    const MockParticipantManager = await ethers.getContractFactory("MockParticipantManager");
    participantManager = await MockParticipantManager.deploy();
    await participantManager.waitForDeployment();
    // Set addr1 participants
    await participantManager.mockSetParticipant(addr1.address, true);

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
        participantManager.address,
        await nuvoLock.getAddress(),
        depositManager.address,
        await owner.getAddress(),
      ],
      { initializer: "initialize" }
    );
    await votingManager.waitForDeployment();
  });

  it("Should initialize with correct parameters", async function () {
    expect(await votingManager.participantManager()).to.equal(participantManager.address);
    expect(await votingManager.nuvoLock()).to.equal(await nuvoLock.getAddress());
    expect(await votingManager.depositManager()).to.equal(depositManager.address);
    expect(await votingManager.owner()).to.equal(await owner.getAddress());
  });

  it("Should only allow owner to initialize", async function () {
    const VotingManager = await ethers.getContractFactory("VotingManager");
    await expect(
      upgrades.deployProxy(
        VotingManager,
        [
          participantManager.address,
          await nuvoLock.getAddress(),
          depositManager.address,
          addr1.address,
        ],
        { initializer: "initialize" }
      )
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });
});
