const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Deposit Information Submission", function () {
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

    // Add addr1 as a participant
    await votingManager.addParticipant(addr1.address, "0x", "0x");
  });

  it("Should allow the current submitter to submit deposit info", async function () {
    await expect(votingManager.submitDepositInfo(addr1.address, 100, "0x1234", 1, "0x5678", "0x"))
      .to.emit(votingManager, "DepositInfoSubmitted")
      .withArgs(addr1.address, 100, "0x1234", 1, "0x5678");

    // Additional checks can be added to verify deposit was recorded in the MockDepositManager
  });

  it("Should revert if non-current submitter tries to submit deposit info", async function () {
    await expect(
      votingManager
        .connect(addr1)
        .submitDepositInfo(addr1.address, 100, "0x1234", 1, "0x5678", "0x")
    ).to.be.revertedWith("Not the current submitter");
  });

  it("Should revert if signature verification fails", async function () {
    // Attempt to submit deposit info with an invalid signature
    await expect(
      votingManager.submitDepositInfo(
        addr1.address,
        100,
        "0x1234",
        1,
        "0x5678",
        "0xInvalidSignature"
      )
    ).to.be.revertedWith("Invalid signature");
  });
});
