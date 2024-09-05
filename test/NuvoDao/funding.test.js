const { expect } = require("chai");
const { ethers } = require("hardhat");
const { setupContracts } = require("./setup");

describe("Funding", function () {
  let dao, member1, multisigWallet, erc20Token;

  before(async function () {
    const setup = await setupContracts();
    dao = setup.dao;
    member1 = setup.member1;
    multisigWallet = setup.multisigWallet;

    // Deploy an ERC20 token for testing
    const ERC20 = await ethers.getContractFactory("ERC20Mock");
    erc20Token = await ERC20.deploy("TestToken", "TT", ethers.parseEther("1000000"));
    await erc20Token.waitForDeployment();
  });

  it("should handle funding proposals with native cryptocurrency", async function () {
    await dao.connect(member1).createProposal(
      "Fund Development",
      60 * 60 * 24 * 3, // 3-day voting period
      1, // ProposalType.Funding
      0, // ProposalCategory.Budget
      ethers.utils.defaultAbiCoder.encode(
        ["address", "uint256", "address", "string"],
        [member1.address, ethers.parseEther("10"), ethers.ZeroAddress, "Development Fund"]
      ),
      { value: ethers.parseEther("1") }
    );

    const proposalId = 1; // First proposal ID
    await dao.connect(member1).vote(proposalId, 1);
    await ethers.provider.send("evm_increaseTime", [60 * 60 * 24 * 4]); // Fast forward 4 days
    await dao.connect(multisigWallet).executeProposal(proposalId);

    expect(await ethers.provider.getBalance(member1.address)).to.equal(ethers.parseEther("10"));
  });

  it("should handle funding proposals with ERC20 tokens", async function () {
    await erc20Token.transfer(dao.address, ethers.parseEther("100"));

    await dao.connect(member1).createProposal(
      "Fund Marketing",
      60 * 60 * 24 * 3, // 3-day voting period
      1, // ProposalType.Funding
      0, // ProposalCategory.Budget
      ethers.utils.defaultAbiCoder.encode(
        ["address", "uint256", "address", "string"],
        [member1.address, ethers.parseEther("50"), erc20Token.address, "Marketing Fund"]
      ),
      { value: ethers.parseEther("1") }
    );

    const proposalId = 2; // Second proposal ID
    await dao.connect(member1).vote(proposalId, 1);
    await ethers.provider.send("evm_increaseTime", [60 * 60 * 24 * 4]); // Fast forward 4 days
    await dao.connect(multisigWallet).executeProposal(proposalId);

    expect(await erc20Token.balanceOf(member1.address)).to.equal(ethers.parseEther("50"));
  });

  // Additional funding tests...
});
