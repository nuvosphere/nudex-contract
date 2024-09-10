const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Submitter Management", function () {
  let votingManager, participantManager, nuvoLock, depositManager, owner, addr1, addr2, addr3;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    address1 = await addr1.getAddress();
    address2 = await addr2.getAddress();

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
        ethers.ZeroAddress, // account manager
        await assetManager.getAddress(), // asset manager
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

  it("Should correctly rotate submitter after each operation", async function () {
    // Simulate adding participants
    await votingManager.addParticipant(address1, "0x", "0x");
    await votingManager.addParticipant(address2, "0x", "0x");

    const currentSubmitter = await votingManager.getCurrentSubmitter();
    expect([address1, address2]).to.include(currentSubmitter);

    // Simulate a task and rotate the submitter
    await votingManager.submitDepositInfo(address1, 100, "0x", 1, "0x", "0x");

    const newSubmitter = await votingManager.getCurrentSubmitter();
    expect(newSubmitter).to.not.equal(currentSubmitter);
  });

  it("Should revert if non-participant tries to rotate submitter", async function () {
    await expect(
      votingManager.connect(addr3).chooseNewSubmitter(address1, "0x", "0x")
    ).to.be.revertedWith("Not a participant");
  });

  it("Should allow only the current submitter to perform actions", async function () {
    await votingManager.addParticipant(address1, "0x", "0x");
    await votingManager.addParticipant(address2, "0x", "0x");

    const currentSubmitter = await votingManager.getCurrentSubmitter();

    if (currentSubmitter === address1) {
      await expect(
        votingManager.connect(addr2).submitDepositInfo(address1, 100, "0x", 1, "0x", "0x")
      ).to.be.revertedWith("Not the current submitter");
    } else {
      await expect(
        votingManager.connect(addr1).submitDepositInfo(address1, 100, "0x", 1, "0x", "0x")
      ).to.be.revertedWith("Not the current submitter");
    }
  });

  it("Should correctly apply demerit points if tasks are incomplete after the threshold", async function () {
    await votingManager.addParticipant(address1, "0x", "0x");

    // Simulate time passing and task incompletion
    await ethers.provider.send("evm_increaseTime", [1 * 60 * 60 * 2]); // 2 hours
    await ethers.provider.send("evm_mine");

    await votingManager.chooseNewSubmitter(address1, "0x", "0x");

    const lockInfo = await nuvoLock.getLockInfo(address1);
    expect(lockInfo.demeritPoints).to.be.gt(0); // Assuming demerit points were applied
  });
});
