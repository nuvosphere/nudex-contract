const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Edge Cases and Advanced Scenarios", function () {
  let votingManager, participantManager, nuvoLock, depositManager, owner, addr1, addr2, addr3;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    address1 = await addr1.getAddress();
    address2 = await addr2.getAddress();

    // Deploy enhanced mock contracts
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
        participantManager.address,
        await nuvoLock.getAddress(),
        depositManager.address,
        await owner.getAddress(),
      ],
      { initializer: "initialize" }
    );
    await votingManager.waitForDeployment();

    // Simulate adding participants
    await participantManager.mockSetParticipant(address1, true);
    await participantManager.mockSetParticipant(address2, true);
  });

  it("Should revert if a non-participant tries to rotate submitter", async function () {
    await expect(
      votingManager.connect(addr3).chooseNewSubmitter(address1, "0x", "0x")
    ).to.be.revertedWith("Not a participant");
  });

  it("Should correctly handle submitter rotation when no tasks have been completed", async function () {
    await participantManager.addParticipant(addr3.address);
    const initialSubmitter = await votingManager.getCurrentSubmitter();

    // Simulate time passing without task completion
    await ethers.provider.send("evm_increaseTime", [2 * 60 * 60]); // 2 hours
    await ethers.provider.send("evm_mine");

    await votingManager.chooseNewSubmitter(initialSubmitter, "0x", "0x");

    const newSubmitter = await votingManager.getCurrentSubmitter();
    expect(newSubmitter).to.not.equal(initialSubmitter);
  });

  it("Should correctly apply demerit points if tasks are incomplete after the threshold", async function () {
    await participantManager.addParticipant(addr3.address);

    // Simulate time passing and task incompletion
    await ethers.provider.send("evm_increaseTime", [1 * 60 * 60 * 2]); // 2 hours
    await ethers.provider.send("evm_mine");

    const initialSubmitter = await votingManager.getCurrentSubmitter();
    await votingManager.chooseNewSubmitter(initialSubmitter, "0x", "0x");

    const lockInfo = await nuvoLock.getLockInfo(initialSubmitter);
    expect(lockInfo.demeritPoints).to.be.gt(0); // Assuming demerit points were applied
  });

  it("Should revert if trying to add a participant when the same address is already a participant", async function () {
    await expect(votingManager.addParticipant(address1, "0x", "0x")).to.be.revertedWith(
      "Already a participant"
    );
  });

  it("Should correctly reset and re-add a participant after removal", async function () {
    await votingManager.removeParticipant(address1, "0x", "0x");

    expect(await participantManager.isParticipant(address1)).to.be.false;

    await votingManager.addParticipant(address1, "0x", "0x");

    expect(await participantManager.isParticipant(address1)).to.be.true;
  });

  it("Should handle the rotation of submitters when the last submitter is removed", async function () {
    // Add and remove participants
    await votingManager.addParticipant(addr3.address, "0x", "0x");
    await votingManager.removeParticipant(address2, "0x", "0x");
    await votingManager.removeParticipant(address1, "0x", "0x");

    const currentSubmitter = await votingManager.getCurrentSubmitter();
    expect(currentSubmitter).to.equal(addr3.address);
  });

  it("Should not allow submitter rotation before the forced rotation window", async function () {
    const initialSubmitter = await votingManager.getCurrentSubmitter();

    await expect(votingManager.chooseNewSubmitter(initialSubmitter, "0x", "0x")).to.be.revertedWith(
      "Submitter rotation not allowed yet"
    );
  });
});
