const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Edge Cases and Advanced Scenarios", function () {
  let votingManager,
    depositManager,
    nuDexOperation,
    participantManager,
    nuvoLock,
    owner,
    addr1,
    addr2,
    addr3,
    address1,
    address2,
    address3;
  let initialSubmitter;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    address1 = await addr1.getAddress();
    address2 = await addr2.getAddress();
    address3 = await addr3.getAddress();

    // Deploy enhanced mock contracts
    const MockDepositManager = await ethers.getContractFactory("MockDepositManager");
    depositManager = await MockDepositManager.deploy();
    await depositManager.waitForDeployment();

    const MockNuDexOperations = await ethers.getContractFactory("MockNuDexOperations");
    nuDexOperation = await MockNuDexOperations.deploy();
    await nuDexOperation.waitForDeployment();

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
        ethers.ZeroAddress, // account manager
        ethers.ZeroAddress, // asset manager
        await depositManager.getAddress(), // deposit manager
        await participantManager.getAddress(), // participant manager
        await nuDexOperation.getAddress(), // nuDex operation
        await nuvoLock.getAddress(), // nuvoLock
        await owner.getAddress(), // owner
      ],
      { initializer: "initialize" }
    );
    await votingManager.waitForDeployment();

    // Simulate adding participants
    await participantManager.addParticipant(address1);
    await participantManager.addParticipant(address2);
    await participantManager.addParticipant(await owner.getAddress());

    // generate signature
    initialSubmitter = await votingManager.getCurrentSubmitter();
    // const rawMessage = ethers.solidityPacked(["address"], [initialSubmitter]);
    // const message = ethers.solidityPackedKeccak256(
    //   ["string", "bytes"],
    //   [((rawMessage.length - 2) / 2).toString(), rawMessage]
    // );
    // signature = await addr1.signMessage(ethers.toBeArray(message));
    signature = generateSigForAddress(initialSubmitter, addr1);
  });

  it("Should revert if a non-participant tries to rotate submitter", async function () {
    await expect(
      votingManager.connect(addr3).chooseNewSubmitter(address1, signature)
    ).to.be.revertedWith("Not a participant");
  });

  it("Should correctly handle submitter rotation when no tasks have been completed", async function () {
    await participantManager.addParticipant(address3);

    // Simulate time passing without task completion
    await ethers.provider.send("evm_increaseTime", [2 * 60 * 60]); // 2 hours
    await ethers.provider.send("evm_mine");

    console.log(" current: ", await votingManager.getCurrentSubmitter(), initialSubmitter);
    await votingManager.connect(addr1).chooseNewSubmitter(initialSubmitter, signature);

    const newSubmitter = await votingManager.getCurrentSubmitter();
    expect(newSubmitter).to.not.equal(initialSubmitter);
  });

  it("Should revert if trying to add a participant when the same address is already a participant", async function () {
    await expect(
      votingManager.connect(addr1).addParticipant(address1, signature)
    ).to.be.revertedWith("Already a participant");
  });

  it("Should correctly reset and re-add a participant after removal", async function () {
    await votingManager.connect(addr1).removeParticipant(address1, signature);
    expect(await participantManager.isParticipant(address1)).to.be.false;

    await participantManager.setParticipant(
      await votingManager.lastSubmitterIndex(),
      await owner.getAddress()
    );
    signature = generateSigForAddress(address1, owner);
    await votingManager.connect(owner).addParticipant(address1, signature);
    expect(await participantManager.isParticipant(address1)).to.be.true;
  });

  it("Should not allow submitter rotation before the forced rotation window", async function () {
    await expect(votingManager.chooseNewSubmitter(initialSubmitter, signature)).to.be.revertedWith(
      "Submitter rotation not allowed yet"
    );
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
