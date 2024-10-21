const { expect } = require("chai");
const { setupContracts } = require("./setup");

describe("Rewards", function () {
  let dao, member1;
  let minLockDuration;

  before(async function () {
    const setup = await setupContracts();
    dao = setup.dao;
    member1 = setup.member1;
    minLockDuration = setup.MIN_LOCK_DURATION;
    await ethers.provider.send("evm_increaseTime", [minLockDuration]); // Fast forward 3 days makes the sender a valid member
  });

  it("should reward participants for voting", async function () {
    await dao.connect(member1).createProposal(
      "Reward Proposal",
      60 * 60 * 24 * 3, // 3-day voting period
      0, // ProposalType.Basic
      1, // ProposalCategory.Policy
      ethers.solidityPacked(["uint256"], [0]),
      { value: ethers.parseEther("1") }
    );

    const proposalId = 1; // First proposal ID
    await dao.connect(member1).vote(proposalId, 2); // Cast 2 votes
    await ethers.provider.send("evm_increaseTime", [60 * 60 * 24 * 4]); // Fast forward 4 days
    await expect(dao.connect(member1).claimRewards())
      .to.emit(dao, "RewardClaimed")
      .withArgs(await member1.getAddress(), 4);
  });

  // Additional rewards tests...
});
