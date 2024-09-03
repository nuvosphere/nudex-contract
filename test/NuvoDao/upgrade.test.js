const { expect } = require("chai");
const { setupContracts } = require("./setup");

describe("Self-Upgradability", function () {
  let dao, proxy, admin, member1;

  before(async function () {
    const setup = await setupContracts();
    dao = setup.dao;
    proxy = setup.proxy;
    admin = setup.admin;
    member1 = setup.member1;
  });

  it("should upgrade the logic contract after a successful vote", async function () {
    // Deploy new logic contract
    const NewDAOLogic = await ethers.getContractFactory("NuvoDAOLogic");
    const newLogicInstance = await NewDAOLogic.deploy(
      admin.address,
      admin.address,
      30, // New quorumPercentage
      ethers.parseEther("2"), // New proposalFee
      60 * 60 * 24, // executionDelay (1 day)
      ethers.parseEther("200"), // New fundingThreshold
      2 // New reputationDecayRate
    );
    await newLogicInstance.waitForDeployment();

    await dao.connect(member1).createProposal(
      "Upgrade to new logic",
      60 * 60 * 24 * 3, // 3-day voting period
      4, // ProposalType.Upgrade
      1, // ProposalCategory.Policy
      ethers.utils.defaultAbiCoder.encode(["address"], [newLogicInstance.address]),
      { value: ethers.parseEther("1") }
    );

    const proposalId = 1; // First proposal ID
    await dao.connect(member1).vote(proposalId, 1);
    await ethers.provider.send("evm_increaseTime", [60 * 60 * 24 * 4]); // Fast forward 4 days
    await dao.connect(admin).executeProposal(proposalId);

    // Check if the proxy was upgraded to the new implementation
    expect(await proxy.implementation()).to.equal(newLogicInstance.address);
  });

  // Additional upgrade tests...
});
