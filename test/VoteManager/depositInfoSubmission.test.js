const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Deposit Information Submission", function () {
  let votingManager, participantManager, nuvoLock, depositManager, owner, addr1;

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

    const MockDepositManager = await ethers.getContractFactory("MockDepositManager");
    depositManager = await MockDepositManager.deploy();
    await depositManager.waitForDeployment();

    // Deploy VotingManager
    const VotingManager = await ethers.getContractFactory("VotingManager");
    votingManager = await upgrades.deployProxy(
      VotingManager,
      [
        await participantManager.getAddress(),
        await nuvoLock.getAddress(),
        ethers.ZeroAddress,
        await depositManager.getAddress(),
        ethers.ZeroAddress,
        await owner.getAddress(),
      ],
      { initializer: "initialize" }
    );
    await votingManager.waitForDeployment();

    // Add addr1 as a participant
    await votingManager.addParticipant(address1, "0x", "0x");
    await participantManager.setParticipant(await votingManager.lastSubmitterIndex());

    const rawMessage = ethers.solidityPacked(
      ["address", "uint", "bytes", "uint", "bytes"],
      [address1, 100, "0x1234", 1, "0x5678"]
    );
    const message = ethers.solidityPackedKeccak256(
      ["string", "bytes"],
      [((rawMessage.length - 2) / 2).toString(), rawMessage]
    );
    signature = await addr1.signMessage(ethers.toBeArray(message));
  });

  it("Should allow the current submitter to submit deposit info", async function () {
    await expect(votingManager.submitDepositInfo(address1, 100, "0x1234", 1, "0x5678", signature))
      .to.emit(votingManager, "DepositInfoSubmitted")
      .withArgs(address1, 100, "0x1234", 1, "0x5678");

    // Additional checks can be added to verify deposit was recorded in the MockDepositManager
  });

  it("Should revert if non-current submitter tries to submit deposit info", async function () {
    // set the submitter other than msg.sender
    await participantManager.setParticipant(
      (await votingManager.lastSubmitterIndex()) >= 9 ? 1 : 9
    );
    await expect(
      votingManager
        .connect(addr1)
        .submitDepositInfo(address1, 100, "0x1234", 1, "0x5678", signature)
    ).to.be.revertedWith("Not the current submitter");
  });

  it("Should revert if signature verification fails", async function () {
    signature = signature.replace("1", "2"); // create a invalid signature
    // Attempt to submit deposit info with an invalid signature
    await expect(
      votingManager.submitDepositInfo(address1, 100, "0x1234", 1, "0x5678", signature)
    ).to.be.revertedWith("Invalid signature");
  });
});
