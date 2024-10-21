const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Reward Voting", function () {
  let votingManager, participantManager, nuvoLock, owner, addr1, address1;
  let signature;
  const newRewardPerPeriod = ethers.parseUnits("10", 18);

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    address1 = await addr1.getAddress();

    // Deploy mock contracts
    const MockParticipantManager = await ethers.getContractFactory("MockParticipantManager");
    participantManager = await MockParticipantManager.deploy();
    await participantManager.waitForDeployment();
    // Set participants
    await participantManager.addParticipant(await owner.getAddress());
    await participantManager.addParticipant(address1);

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

    // generate signature
    const rawMessage = ethers.solidityPacked(["uint"], [newRewardPerPeriod]);
    const message = ethers.solidityPackedKeccak256(
      ["string", "bytes"],
      [((rawMessage.length - 2) / 2).toString(), rawMessage]
    );
    signature = await owner.signMessage(ethers.toBeArray(message));
  });

  it("Should allow the current submitter to set reward per period", async function () {
    await expect(votingManager.setRewardPerPeriod(newRewardPerPeriod, signature))
      .to.emit(votingManager, "RewardPerPeriodVoted")
      .withArgs(newRewardPerPeriod);

    expect(await nuvoLock.rewardPerPeriod(0)).to.equal(newRewardPerPeriod);
  });

  it("Should revert if non-current submitter tries to set reward per period", async function () {
    await expect(
      votingManager.connect(addr1).setRewardPerPeriod(newRewardPerPeriod, signature)
    ).to.be.revertedWith("Not the current submitter");
  });
});
