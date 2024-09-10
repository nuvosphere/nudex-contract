const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Participant Management", function () {
  let votingManager, participantManager, nuvoLock, owner, addr1, addr2, address1, address2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    address1 = await addr1.getAddress();
    address2 = await addr2.getAddress();

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
        ethers.ZeroAddress, // account manager
        ethers.ZeroAddress, // asset manager
        ethers.ZeroAddress, // deposit manager
        await participantManager.getAddress(), // participant manager
        ethers.ZeroAddress, // nuDex operation
        await nuvoLock.getAddress(), // nuvoLock
        await owner.getAddress(), // owner
      ],
      { initializer: "initialize" }
    );
    await votingManager.waitForDeployment();

    // Add addr1 as a participant
    await participantManager.addParticipant(address1);

    // generate signature
    signature = await generateSigForAddress(address1, addr1);
  });

  it("Should allow the current submitter to add a new participant", async function () {
    expect(await participantManager.isParticipant(address2)).to.be.false;

    // Simulate adding a new participant
    signature = await generateSigForAddress(address2, addr1);
    await votingManager.connect(addr1).addParticipant(address2, signature);

    expect(await participantManager.isParticipant(address2)).to.be.true;
  });

  it("Should revert if non-current submitter tries to add a participant", async function () {
    // set the address to non-current submitter
    await participantManager.setParticipant(
      await votingManager.lastSubmitterIndex(),
      ethers.ZeroAddress
    );
    // Trying to add a participant from a non-current submitter
    await expect(votingManager.connect(addr2).addParticipant(address1, "0x")).to.be.revertedWith(
      "Not the current submitter"
    );
  });

  it("Should allow the current submitter to remove a participant", async function () {
    // Add another participant so after remove it has at least one participant left
    await participantManager.addParticipant(address2);
    await votingManager.connect(addr1).removeParticipant(address1, signature);
    expect(await participantManager.isParticipant(address1)).to.be.false;
  });

  it("Should revert if non-current submitter tries to remove a participant", async function () {
    // Add address2 as another participant
    await participantManager.addParticipant(address2);
    // set the address to non-current submitter
    await participantManager.setParticipant(await votingManager.lastSubmitterIndex(), address2);
    // Trying to remove the participant from a non-current submitter
    await expect(
      votingManager.connect(addr1).removeParticipant(address1, signature)
    ).to.be.revertedWith("Not the current submitter");
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
