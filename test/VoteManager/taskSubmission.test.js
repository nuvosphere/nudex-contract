const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Task Submission and Completion", function () {
  let votingManager, participantManager, nuDexOperation, nuvoLock, owner, addr1, address1;
  let signature;

  const taskId = 1;
  const result = "0x";

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    address1 = await addr1.getAddress();

    // Deploy mock contracts
    const MockParticipantManager = await ethers.getContractFactory("MockParticipantManager");
    participantManager = await MockParticipantManager.deploy();
    await participantManager.waitForDeployment();
    // Set participants
    await participantManager.addParticipant(address1);

    const MockNuDexOperations = await ethers.getContractFactory("MockNuDexOperations");
    nuDexOperation = await MockNuDexOperations.deploy();
    await nuDexOperation.waitForDeployment();

    const MockNuvoLockUpgradeable = await ethers.getContractFactory("MockNuvoLockUpgradeable");
    nuvoLock = await MockNuvoLockUpgradeable.deploy();
    await nuvoLock.waitForDeployment();

    // Deploy VotingManager
    const VotingManager = await ethers.getContractFactory("VotingManager");
    votingManager = await upgrades.deployProxy(
      VotingManager,
      [
        ethers.ZeroAddress, // account manager
        ethers.ZeroAddress, // asset manager
        ethers.ZeroAddress, // deposit manager
        await participantManager.getAddress(), // participant manager
        await nuDexOperation.getAddress(), // nuDex operation
        await nuvoLock.getAddress(), // nuvoLock
        await owner.getAddress(), // owner
      ],
      { initializer: "initialize" }
    );
    await votingManager.waitForDeployment();

    // generate signature
    const rawMessage = ethers.solidityPacked(["uint", "bytes"], [taskId, result]);
    const message = ethers.solidityPackedKeccak256(
      ["string", "bytes"],
      [((rawMessage.length - 2) / 2).toString(), rawMessage]
    );
    signature = await addr1.signMessage(ethers.toBeArray(message));
  });

  it("Should allow the current submitter to submit a task", async function () {
    console.log(
      await ethers.provider.getBlockNumber(),
      (await ethers.provider.getBlock()).timestamp
    );
    await expect(votingManager.connect(addr1).submitTaskReceipt(taskId, result, signature))
      .to.emit(votingManager, "TaskCompleted")
      .withArgs(taskId, address1, (await ethers.provider.getBlock("latest")).timestamp, result);
  });

  it("Should revert if task is already completed", async function () {
    await votingManager.connect(addr1).submitTaskReceipt(taskId, result, signature);

    // Attempt to submit the same task again
    await expect(
      votingManager.connect(addr1).submitTaskReceipt(taskId, result, signature)
    ).to.be.revertedWith("Task already completed");
  });

  it("Should revert if signature verification fails", async function () {
    signature = signature.replace("1", "2"); // create a invalid signature
    await expect(
      votingManager.connect(addr1).submitTaskReceipt(taskId, result, signature)
    ).to.be.revertedWith("Invalid signature");
  });
});
