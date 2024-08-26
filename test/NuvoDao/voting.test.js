const { expect } = require("chai");
const { setupContracts } = require("./setup");

describe("Voting", function () {
    let dao, member1, member2;

    before(async function () {
        const setup = await setupContracts();
        dao = setup.dao;
        member1 = setup.member1;
        member2 = setup.member2;
    });

    it("should allow quadratic voting", async function () {
        await dao.connect(member1).createProposal(
            "Simple Proposal",
            60 * 60 * 24 * 3, // 3-day voting period
            0, // ProposalType.Basic
            1, // ProposalCategory.Policy
            ethers.utils.defaultAbiCoder.encode(
                ["uint256"],
                [0]
            ),
            { value: ethers.utils.parseEther("1") }
        );

        const proposalId = 1; // First proposal ID
        await dao.connect(member1).vote(proposalId, 3); // Cast 3 votes (quadratic cost = 9)
        const proposal = await dao.proposals(proposalId);
        expect(proposal.voteCount).to.equal(9); // Quadratic voting
    });

    it("should allow vote delegation", async function () {
        await dao.connect(member2).delegateVote(member1.address);

        await dao.connect(member1).createProposal(
            "Delegated Vote Proposal",
            60 * 60 * 24 * 3, // 3-day voting period
            0, // ProposalType.Basic
            1, // ProposalCategory.Policy
            ethers.utils.defaultAbiCoder.encode(
                ["uint256"],
                [0]
            ),
            { value: ethers.utils.parseEther("1") }
        );

        const proposalId = 2; // Second proposal ID
        await dao.connect(member1).vote(proposalId, 1); // Cast 1 vote, but member1 has votes delegated by member2
        const proposal = await dao.proposals(proposalId);
        expect(proposal.voteCount).to.be.above(1); // Delegated votes included
    });

    // Additional voting tests...
});
