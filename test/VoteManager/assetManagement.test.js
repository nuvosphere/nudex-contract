const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Asset Management", function () {
  let votingManager, participantManager, nuvoLock, assetManager, owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();

    // Deploy mock contracts
    const MockParticipantManager = await ethers.getContractFactory("MockParticipantManager");
    participantManager = await MockParticipantManager.deploy();
    await participantManager.waitForDeployment();
    // Set addr1 participants
    await participantManager.mockSetParticipant(addr1.address, true);

    const MockNuvoLockUpgradeable = await ethers.getContractFactory("MockNuvoLockUpgradeable");
    nuvoLock = await MockNuvoLockUpgradeable.deploy();
    await nuvoLock.waitForDeployment();

    const MockAssetManager = await ethers.getContractFactory("MockAssetManager");
    assetManager = await MockAssetManager.deploy();
    await assetManager.waitForDeployment();

    // Deploy VotingManager
    const VotingManager = await ethers.getContractFactory("VotingManager");
    votingManager = await upgrades.deployProxy(
      VotingManager,
      [
        participantManager.address,
        await nuvoLock.getAddress(),
        ethers.constants.AddressZero,
        await owner.getAddress(),
      ],
      { initializer: "initialize" }
    );
    await votingManager.waitForDeployment();

    // Add addr1 as a participant
    await votingManager.addParticipant(addr1.address, "0x", "0x");
  });

  it("Should allow the current submitter to list a new asset", async function () {
    const assetType = 2; // ERC20
    const assetName = "TestAsset";
    const nuDexName = "TST";
    const contractAddress = addr1.address;
    const chainId = 1;

    await expect(
      votingManager.listAsset(assetName, nuDexName, assetType, contractAddress, chainId, "0x")
    ).to.emit(votingManager, "AssetListed");

    expect(await assetManager.isAssetListed(assetType, contractAddress, chainId)).to.be.true;
  });

  it("Should revert if non-current submitter tries to list a new asset", async function () {
    const assetType = 2; // ERC20
    const assetName = "TestAsset";
    const nuDexName = "TST";
    const contractAddress = addr1.address;
    const chainId = 1;

    await expect(
      votingManager
        .connect(addr1)
        .listAsset(assetName, nuDexName, assetType, contractAddress, chainId, "0x")
    ).to.be.revertedWith("Not the current submitter");
  });

  it("Should allow the current submitter to delist an asset", async function () {
    const assetType = 2; // ERC20
    const contractAddress = addr1.address;
    const chainId = 1;

    // List the asset first
    await votingManager.listAsset("TestAsset", "TST", assetType, contractAddress, chainId, "0x");

    await expect(votingManager.delistAsset(assetType, contractAddress, chainId, "0x")).to.emit(
      votingManager,
      "AssetDelisted"
    );

    expect(await assetManager.isAssetListed(assetType, contractAddress, chainId)).to.be.false;
  });

  it("Should revert if non-current submitter tries to delist an asset", async function () {
    const assetType = 2; // ERC20
    const contractAddress = addr1.address;
    const chainId = 1;

    // List the asset first
    await votingManager.listAsset("TestAsset", "TST", assetType, contractAddress, chainId, "0x");

    await expect(
      votingManager.connect(addr1).delistAsset(assetType, contractAddress, chainId, "0x")
    ).to.be.revertedWith("Not the current submitter");
  });

  it("Should revert if signature verification fails when listing an asset", async function () {
    const assetType = 2; // ERC20
    const assetName = "TestAsset";
    const nuDexName = "TST";
    const contractAddress = addr1.address;
    const chainId = 1;

    await expect(
      votingManager.listAsset(
        assetName,
        nuDexName,
        assetType,
        contractAddress,
        chainId,
        "0xInvalidSignature"
      )
    ).to.be.revertedWith("Invalid signature");
  });

  it("Should revert if signature verification fails when delisting an asset", async function () {
    const assetType = 2; // ERC20
    const contractAddress = addr1.address;
    const chainId = 1;

    // List the asset first
    await votingManager.listAsset("TestAsset", "TST", assetType, contractAddress, chainId, "0x");

    await expect(
      votingManager.delistAsset(assetType, contractAddress, chainId, "0xInvalidSignature")
    ).to.be.revertedWith("Invalid signature");
  });
});
