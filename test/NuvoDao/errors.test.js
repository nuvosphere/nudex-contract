const { expect } = require("chai");
const { setupContracts } = require("./setup");

describe("Errors", function () {
  let dao, nuvoLock, admin, member1, member2;
  let minLockDuration;

  before(async function () {
    const setup = await setupContracts();
    dao = setup.dao;
    admin = setup.admin;
    member1 = setup.member1;
    member2 = setup.member2;
    nuvoLock = setup.nuvoLock;
    minLockDuration = setup.MIN_LOCK_DURATION;

    await ethers.provider.send("evm_increaseTime", [minLockDuration]); // Fast forward 3 days makes the sender a valid member
  });

  it("should revert if non-member tries to vote", async function () {
    await expect(dao.connect(member2).vote(1, 1)).to.be.revertedWith(
      "You must lock at least 10,000 Nuvo tokens for 3 days to participate."
    );
  });

  it("should revert if a proposal is executed before voting period ends", async function () {
    await dao.connect(member1).createProposal(
      "Early Execution Test",
      minLockDuration, // 3-day voting period
      0, // ProposalType.Basic
      1, // ProposalCategory.Policy
      ethers.solidityPacked(["uint256"], [0]),
      { value: ethers.parseEther("1") }
    );

    const proposalId = await dao.proposalId(); // First proposal ID
    await dao.connect(member1).vote(proposalId, 1);

    await expect(dao.connect(admin).executeProposal(proposalId)).to.be.revertedWith(
      "Voting period is not over yet"
    );
  });

  it("should revert if a funding proposal tries to withdraw more than available balance", async function () {
    await dao.connect(member1).createProposal(
      "Overdraw Test",
      minLockDuration, // 3-day voting period
      1, // ProposalType.Funding
      0, // ProposalCategory.Budget
      ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address, uint256, address, string)"],
        [
          [
            await member1.getAddress(),
            ethers.parseEther("1000"),
            ethers.ZeroAddress,
            "Overdraw Test",
          ],
        ]
      ),
      { value: ethers.parseEther("1") }
    );

    const proposalId = 2; // Second proposal ID
    await dao.connect(member1).vote(proposalId, BigInt(10 ** 11));
    await ethers.provider.send("evm_increaseTime", [60 * 60 * 24 * 4]); // Fast forward 4 days

    await expect(dao.connect(admin).executeProposal(proposalId)).to.be.revertedWith(
      "Insufficient balance"
    );
  });

  // Additional error cases...
});
