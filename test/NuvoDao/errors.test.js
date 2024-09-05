const { expect } = require("chai");
const { setupContracts } = require("./setup");

describe("Errors", function () {
  let dao, member1, member2;

  before(async function () {
    const setup = await setupContracts();
    dao = setup.dao;
    member1 = setup.member1;
    member2 = setup.member2;
  });

  it("should revert if non-member tries to vote", async function () {
    await expect(dao.connect(member2).vote(1, 1)).to.be.revertedWith(
      "You must lock at least 10,000 Nuvo tokens for 3 days to participate."
    );
  });

  it("should revert if a proposal is executed before voting period ends", async function () {
    await dao.connect(member1).createProposal(
      "Early Execution Test",
      60 * 60 * 24 * 3, // 3-day voting period
      0, // ProposalType.Basic
      1, // ProposalCategory.Policy
      ethers.utils.defaultAbiCoder.encode(["uint256"], [0]),
      { value: ethers.parseEther("1") }
    );

    const proposalId = 1; // First proposal ID
    await dao.connect(member1).vote(proposalId, 1);

    await expect(dao.connect(member1).executeProposal(proposalId)).to.be.revertedWith(
      "Voting period is not over yet"
    );
  });

  it("should revert if a funding proposal tries to withdraw more than available balance", async function () {
    await dao.connect(member1).createProposal(
      "Overdraw Test",
      60 * 60 * 24 * 3, // 3-day voting period
      1, // ProposalType.Funding
      0, // ProposalCategory.Budget
      ethers.utils.defaultAbiCoder.encode(
        ["address", "uint256", "address", "string"],
        [member1.address, ethers.parseEther("1000"), ethers.ZeroAddress, "Overdraw Test"]
      ),
      { value: ethers.parseEther("1") }
    );

    const proposalId = 2; // Second proposal ID
    await dao.connect(member1).vote(proposalId, 1);
    await ethers.provider.send("evm_increaseTime", [60 * 60 * 24 * 4]); // Fast forward 4 days

    await expect(dao.connect(member1).executeProposal(proposalId)).to.be.revertedWith(
      "Insufficient balance"
    );
  });

  // Additional error cases...
});
