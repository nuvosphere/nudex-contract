const { expect } = require("chai");
const { setupContracts } = require("./setup");

describe("Governance", function () {
  let dao, admin, member1;

  before(async function () {
    const setup = await setupContracts();
    dao = setup.dao;
    admin = setup.admin;
    member1 = setup.member1;
  });

  it("should allow setting quorum percentage via governance proposal", async function () {
    await dao.connect(member1).createProposal(
      "Change Quorum to 25%",
      60 * 60 * 24 * 3, // 3-day voting period
      2, // ProposalType.Governance
      1, // ProposalCategory.Policy
      ethers.utils.defaultAbiCoder.encode(
        ["uint256", "uint256", "uint256", "uint256", "uint256"],
        [25, 0, 0, 0, 0] // Change quorumPercentage to 25%
      ),
      { value: ethers.parseEther("1") }
    );

    const proposalId = 1; // First proposal ID
    await dao.connect(member1).vote(proposalId, 1);
    await ethers.provider.send("evm_increaseTime", [60 * 60 * 24 * 4]); // Fast forward 4 days
    await dao.connect(admin).executeProposal(proposalId);

    const quorumPercentage = await dao.quorumPercentage();
    expect(quorumPercentage).to.equal(25);
  });

  // Additional governance parameter tests...
});
