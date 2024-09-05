const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Asset Management", function () {
  let votingManager, participantManager, nuvoLock, assetManager, owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    address1 = await addr1.getAddress();

    // Deploy mock contracts
    const MockParticipantManager = await ethers.getContractFactory("MockParticipantManager");
    participantManager = await MockParticipantManager.deploy();
    await participantManager.waitForDeployment();

    const MockNuvoLockUpgradeable = await ethers.getContractFactory("MockNuvoLockUpgradeable");
    nuvoLock = await MockNuvoLockUpgradeable.deploy();
    await nuvoLock.waitForDeployment();

    const MockAssetManager = await ethers.getContractFactory("MockAssetManager");
    assetManager = await MockAssetManager.deploy();
    await assetManager.waitForDeployment();

    // const MockDepositManager = await ethers.getContractFactory("MockDepositManager");
    // depositManager = await MockDepositManager.deploy();
    // await depositManager.waitForDeployment();

    // Deploy VotingManager
    const VotingManager = await ethers.getContractFactory("VotingManager");
    votingManager = await upgrades.deployProxy(
      VotingManager,
      [
        await participantManager.getAddress(),
        await nuvoLock.getAddress(),
        ethers.ZeroAddress,
        ethers.ZeroAddress,
        ethers.ZeroAddress,
        await owner.getAddress(),
      ],
      { initializer: "initialize" }
    );
    await votingManager.waitForDeployment();

    // Add addr1 as a participant
    const rawMessage = ethers.solidityPacked(["address"], [address1]);
    const message = ethers.solidityPackedKeccak256(
      ["string", "bytes"],
      [rawMessage.length.toString(), rawMessage]
    );
    const rawSignature = await addr1.signMessage(ethers.toBeArray(message));
    await votingManager.addParticipant(address1, "0x", rawSignature);
  });

  it("Should allow the current submitter to list a new asset", async function () {
    const assetType = 2; // ERC20
    const assetName = "TestAsset";
    const nuDexName = "TST";
    const contractAddress = address1;
    const chainId = 1;

    const rawMessage = ethers.solidityPacked(
      ["string", "string", "uint", "address", "uint"],
      [assetName, nuDexName, assetType, contractAddress, chainId]
    );
    const message = ethers.solidityPackedKeccak256(
      ["string", "bytes"],
      [rawMessage.length.toString(), rawMessage]
    );
    const rawSignature = await addr1.signMessage(ethers.toBeArray(message));
    await expect(
      votingManager.listAsset(
        assetName,
        nuDexName,
        assetType,
        contractAddress,
        chainId,
        rawSignature
      )
    ).to.emit(votingManager, "AssetListed");

    expect(await assetManager.isAssetListed(assetType, contractAddress, chainId)).to.be.true;
  });

  it("Should revert if non-current submitter tries to list a new asset", async function () {
    const assetType = 2; // ERC20
    const assetName = "TestAsset";
    const nuDexName = "TST";
    const contractAddress = address1;
    const chainId = 1;

    await expect(
      votingManager
        .connect(addr1)
        .listAsset(assetName, nuDexName, assetType, contractAddress, chainId, "0x")
    ).to.be.revertedWith("Not the current submitter");
  });

  it("Should allow the current submitter to delist an asset", async function () {
    const assetType = 2; // ERC20
    const contractAddress = address1;
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
    const contractAddress = address1;
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
    const contractAddress = address1;
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
    const contractAddress = address1;
    const chainId = 1;

    // List the asset first
    await votingManager.listAsset("TestAsset", "TST", assetType, contractAddress, chainId, "0x");

    await expect(
      votingManager.delistAsset(assetType, contractAddress, chainId, "0xInvalidSignature")
    ).to.be.revertedWith("Invalid signature");
  });
});
