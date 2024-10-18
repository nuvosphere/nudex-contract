const { expect } = require("chai");
const { ethers } = require("hardhat");
const { setupContracts } = require("./setup");

describe("Funding", function () {
  let dao, admin, member1, multisigWallet, erc20Token;
  let minLockDuration;

  before(async function () {
    const setup = await setupContracts();
    dao = setup.dao;
    admin = setup.admin;
    member1 = setup.member1;
    multisigWallet = setup.multisigWallet;
    minLockDuration = setup.MIN_LOCK_DURATION;

    // Deploy an ERC20 token for testing
    const ERC20 = await ethers.getContractFactory("MockNuvoToken");
    erc20Token = await ERC20.deploy();
    await erc20Token.waitForDeployment();

    await ethers.provider.send("evm_increaseTime", [minLockDuration]); // Fast forward 3 days makes the sender a valid member
  });

  it("should handle funding proposals with native cryptocurrency", async function () {
    await dao.connect(member1).createProposal(
      "Fund Development",
      60 * 60 * 24 * 3, // 3-day voting period
      1, // ProposalType.Funding
      0, // ProposalCategory.Budget
      ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address, uint256, address, string)"],
        [
          [
            await member1.getAddress(),
            ethers.parseEther("10"),
            ethers.ZeroAddress,
            "Development Fund",
          ],
        ]
      ),
      { value: ethers.parseEther("10") }
    );

    const proposalId = 1; // First proposal ID
    await dao.connect(member1).vote(proposalId, BigInt(10 ** 11));
    let initialBalance = await ethers.provider.getBalance(await member1.getAddress());
    await ethers.provider.send("evm_increaseTime", [60 * 60 * 24 * 4]); // Fast forward 4 days
    await dao.connect(admin).executeProposal(proposalId);

    expect(
      (await ethers.provider.getBalance(await member1.getAddress())) - initialBalance
    ).to.equal(ethers.parseEther("10"));
  });

  it("should handle funding proposals with ERC20 tokens", async function () {
    await erc20Token.transfer(await dao.getAddress(), ethers.parseEther("100"));

    await dao.connect(member1).createProposal(
      "Fund Marketing",
      60 * 60 * 24 * 3, // 3-day voting period
      1, // ProposalType.Funding
      0, // ProposalCategory.Budget
      ethers.AbiCoder.defaultAbiCoder().encode(
        ["tuple(address, uint256, address, string)"],
        [
          [
            await member1.getAddress(),
            ethers.parseEther("50"),
            await erc20Token.getAddress(),
            "Marketing Fund",
          ],
        ]
      ),
      { value: ethers.parseEther("1") }
    );

    const proposalId = 2; // Second proposal ID
    await dao.connect(member1).vote(proposalId, BigInt(10 ** 11));
    await ethers.provider.send("evm_increaseTime", [60 * 60 * 24 * 4]); // Fast forward 4 days
    await dao.connect(admin).executeProposal(proposalId);

    expect(await erc20Token.balanceOf(await member1.getAddress())).to.equal(
      ethers.parseEther("50")
    );
  });

  // Additional funding tests...
});
