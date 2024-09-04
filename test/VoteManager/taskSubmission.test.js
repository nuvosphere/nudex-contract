const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Task Submission and Completion", function () {
  let votingManager, participantManager, nuvoLock, owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    address1 = await addr1.getAddress();

    // Deploy mock contracts
    const MockParticipantManager = await ethers.getContractFactory("MockParticipantManager");
    participantManager = await MockParticipantManager.deploy();
    await participantManager.waitForDeployment();

    const MockNuvoLockUpgradeable = await ethers.getContractFactory("MockNuvoLockUpgradeable");
    nuvoLock = await MockNuvoLockUpgradeable.deploy();
    await nuvoLock.waitForDeployment();

    // Deploy VotingManager
    const VotingManager = await ethers.getContractFactory("VotingManager");
    votingManager = await upgrades.deployProxy(
      VotingManager,
      [
        participantManager.address,
        await nuvoLock.getAddress(),
        ethers.constants.AddressZero,
        await owner.getAddress(),
      ],
      { initializer: "initialize" }
    );
    await votingManager.waitForDeployment();

    // Add addr1 as a participant
    await votingManager.addParticipant(address1, "0x", "0x");
  });

  it("Should allow the current submitter to submit a task", async function () {
    const taskId = 1;
    const result = "0xResult";

    await expect(votingManager.submitTaskReceipt(taskId, result, "0x"))
      .to.emit(votingManager, "TaskCompleted")
      .withArgs(taskId, address1, (await ethers.provider.getBlock("latest")).timestamp, result);
  });

  it("Should revert if non-current submitter tries to submit a task", async function () {
    const taskId = 1;
    const result = "0xResult";

    await expect(
      votingManager.connect(addr1).submitTaskReceipt(taskId, result, "0x")
    ).to.be.revertedWith("Not the current submitter");
  });

  it("Should revert if task is already completed", async function () {
    const taskId = 1;
    const result = "0xResult";

    await votingManager.submitTaskReceipt(taskId, result, "0x");

    // Attempt to submit the same task again
    await expect(votingManager.submitTaskReceipt(taskId, result, "0x")).to.be.revertedWith(
      "Task already completed"
    );
  });

  it("Should revert if signature verification fails", async function () {
    const taskId = 1;
    const result = "0xResult";

    await expect(
      votingManager.submitTaskReceipt(taskId, result, "0xInvalidSignature")
    ).to.be.revertedWith("Invalid signature");
  });
});
