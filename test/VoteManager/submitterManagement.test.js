const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Submitter Management", function () {
  let votingManager,
    depositManager,
    nuvoLock,
    participantManager,
    nuDexOperation,
    owner,
    addr1,
    addr2,
    addr3,
    ownerAddress,
    address1,
    address2,
    signature;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    ownerAddress = await owner.getAddress();
    address1 = await addr1.getAddress();
    address2 = await addr2.getAddress();

    // Deploy mock contracts
    const MockParticipantManager = await ethers.getContractFactory("MockParticipantManager");
    participantManager = await MockParticipantManager.deploy();
    await participantManager.waitForDeployment();
    // Set participants
    await participantManager.addParticipant(ownerAddress);

    const MockNuvoLockUpgradeable = await ethers.getContractFactory("MockNuvoLockUpgradeable");
    nuvoLock = await MockNuvoLockUpgradeable.deploy();
    await nuvoLock.waitForDeployment();

    const MockNuDexOperations = await ethers.getContractFactory("MockNuDexOperations");
    nuDexOperation = await MockNuDexOperations.deploy();
    await nuDexOperation.waitForDeployment();

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
        await nuDexOperation.getAddress(), // nuDex operation
        await nuvoLock.getAddress(), // nuvoLock
        ownerAddress, // owner
      ],
      { initializer: "initialize" }
    );
    await votingManager.waitForDeployment();

    // generate signature
    signature = await generateSigForAddress(address1, owner);
  });

  it("Should correctly rotate submitter after each operation", async function () {
    // Simulate adding participants
    await votingManager.addParticipant(address1, signature);
    // mock the current submitter
    await participantManager.setParticipant(await votingManager.lastSubmitterIndex(), ownerAddress);
    signature = await generateSigForAddress(address2, owner);
    await votingManager.addParticipant(address2, signature);

    const currentSubmitter = await votingManager.getCurrentSubmitter();
    expect([ownerAddress, address1, address2]).to.include(currentSubmitter);

    // Simulate a task and rotate the submitter
    // generate signature
    const rawMessage = ethers.solidityPacked(
      ["address", "uint", "bytes", "uint", "bytes"],
      [address1, 100, "0x", 1, "0x"]
    );
    const message = ethers.solidityPackedKeccak256(
      ["string", "bytes"],
      [((rawMessage.length - 2) / 2).toString(), rawMessage]
    );
    signature = await addr1.signMessage(ethers.toBeArray(message));
    // mock the current submitter
    await participantManager.setParticipant(await votingManager.lastSubmitterIndex(), ownerAddress);
    await votingManager.submitDepositInfo(address1, 100, "0x", 1, "0x", signature);

    const newSubmitter = await votingManager.getCurrentSubmitter();
    expect([ownerAddress, address1, address2]).to.include(newSubmitter);
  });

  it("Should revert if non-participant tries to rotate submitter", async function () {
    await expect(
      votingManager.connect(addr3).chooseNewSubmitter(address1, signature)
    ).to.be.revertedWith("Not a participant");
  });

  it("Should allow only the current submitter to perform actions", async function () {
    await votingManager.addParticipant(address1, signature);
    // generate new signature
    signature = await generateSigForAddress(address2, owner);
    // mock the current submitter
    await participantManager.setParticipant(await votingManager.lastSubmitterIndex(), ownerAddress);
    await votingManager.addParticipant(address2, signature);

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
    await votingManager.addParticipant(address1, signature);

    // Simulate time passing and task incompletion
    await ethers.provider.send("evm_increaseTime", [1 * 60 * 60 * 2]); // 2 hours
    await ethers.provider.send("evm_mine");

    // mock the current submitter
    await participantManager.setParticipant(await votingManager.lastSubmitterIndex(), address1);
    await nuDexOperation.submitTask("Test task", 0);
    await votingManager.chooseNewSubmitter(address1, signature);

    const lockInfo = await nuvoLock.getLockInfo(address1);
    expect(lockInfo.demeritPoints).to.be.gt(0); // Assuming demerit points were applied
  });
});

async function generateSigForAddress(addr, signer) {
  const rawMessage = ethers.solidityPacked(["address"], [addr]);
  const message = ethers.solidityPackedKeccak256(
    ["string", "bytes"],
    [((rawMessage.length - 2) / 2).toString(), rawMessage]
  );
  return await signer.signMessage(ethers.toBeArray(message));
}
