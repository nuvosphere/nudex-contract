const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Submitter Management", function () {
  let votingManager, participantManager, nuvoLock, depositManager, owner, addr1, addr2, addr3;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    // Deploy mock contracts
    const MockParticipantManager = await ethers.getContractFactory("MockParticipantManager");
    participantManager = await MockParticipantManager.deploy();
    await participantManager.deployed();

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

  it("Should correctly rotate submitter after each operation", async function () {
    // Simulate adding participants
    await votingManager.addParticipant(addr1.address, "0x", "0x");
    await votingManager.addParticipant(addr2.address, "0x", "0x");

    const currentSubmitter = await votingManager.getCurrentSubmitter();
    expect([addr1.address, addr2.address]).to.include(currentSubmitter);

    // Simulate a task and rotate the submitter
    await votingManager.submitDepositInfo(addr1.address, 100, "0x", 1, "0x", "0x");

    const newSubmitter = await votingManager.getCurrentSubmitter();
    expect(newSubmitter).to.not.equal(currentSubmitter);
  });

  it("Should revert if non-participant tries to rotate submitter", async function () {
    await expect(votingManager.connect(addr3).chooseNewSubmitter(addr1.address, "0x", "0x")).to.be.revertedWith("Not a participant");
  });

  it("Should allow only the current submitter to perform actions", async function () {
    await votingManager.addParticipant(addr1.address, "0x", "0x");
    await votingManager.addParticipant(addr2.address, "0x", "0x");

    const currentSubmitter = await votingManager.getCurrentSubmitter();

    if (currentSubmitter === addr1.address) {
      await expect(votingManager.connect(addr2).submitDepositInfo(addr1.address, 100, "0x", 1, "0x", "0x")).to.be.revertedWith("Not the current submitter");
    } else {
      await expect(votingManager.connect(addr1).submitDepositInfo(addr1.address, 100, "0x", 1, "0x", "0x")).to.be.revertedWith("Not the current submitter");
    }
  });

  it("Should correctly apply demerit points if tasks are incomplete after the threshold", async function () {
    await votingManager.addParticipant(addr1.address, "0x", "0x");

    // Simulate time passing and task incompletion
    await ethers.provider.send("evm_increaseTime", [1 * 60 * 60 * 2]); // 2 hours
    await ethers.provider.send("evm_mine");

    await votingManager.chooseNewSubmitter(addr1.address, "0x", "0x");

    const lockInfo = await nuvoLock.getLockInfo(addr1.address);
    expect(lockInfo.demeritPoints).to.be.gt(0); // Assuming demerit points were applied
  });
});
