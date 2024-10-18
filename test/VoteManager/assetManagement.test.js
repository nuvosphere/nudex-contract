const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VotingManager - Asset Management", function () {
  let votingManager, participantManager, nuvoLock, assetManager, owner, addr1, address1;

  // listAsset params
  let assetType = 2; // ERC20
  let assetName = "TestAsset";
  let nuDexName = "TST";
  let contractAddress;
  let chainId = 1;
  let signature;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    address1 = await addr1.getAddress();
    contractAddress = address1;

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
        ethers.ZeroAddress, // account manager
        await assetManager.getAddress(), // asset manager
        ethers.ZeroAddress, // deposit manager
        await participantManager.getAddress(), // participant manager
        ethers.ZeroAddress, // nuDex operation
        await nuvoLock.getAddress(), // nuvoLock
        await owner.getAddress(), // owner
      ],
      { initializer: "initialize" }
    );
    await votingManager.waitForDeployment();

    // Add addr1 as a participant
    await participantManager.addParticipant(address1);

    // generate signature
    const rawMessage = ethers.solidityPacked(
      ["string", "string", "uint8", "address", "uint"],
      [assetName, nuDexName, assetType, contractAddress, chainId]
    );
    const message = ethers.solidityPackedKeccak256(
      ["string", "bytes"],
      [((rawMessage.length - 2) / 2).toString(), rawMessage]
    );
    signature = await addr1.signMessage(ethers.toBeArray(message));
  });

  it("Should allow the current submitter to list a new asset", async function () {
    await expect(
      votingManager
        .connect(addr1)
        .listAsset(assetName, nuDexName, assetType, contractAddress, chainId, signature)
    ).to.emit(votingManager, "AssetListed");

    expect(await assetManager.isAssetListed(assetType, contractAddress, chainId)).to.be.true;
  });

  it("Should revert if non-current submitter tries to list a new asset", async function () {
    // set the address to non-current submitter
    await participantManager.setParticipant(
      await votingManager.lastSubmitterIndex(),
      ethers.ZeroAddress
    );
    await expect(
      votingManager
        .connect(addr1)
        .listAsset(assetName, nuDexName, assetType, contractAddress, chainId, signature)
    ).to.be.revertedWith("Not the current submitter");
  });

  it("Should allow the current submitter to delist an asset", async function () {
    // List the asset first
    await votingManager
      .connect(addr1)
      .listAsset(assetName, nuDexName, assetType, contractAddress, chainId, signature);

    await participantManager.setParticipant(await votingManager.lastSubmitterIndex(), address1);
    const rawMessage = ethers.solidityPacked(
      ["uint8", "address", "uint"],
      [assetType, contractAddress, chainId]
    );
    const message = ethers.solidityPackedKeccak256(
      ["string", "bytes"],
      [((rawMessage.length - 2) / 2).toString(), rawMessage]
    );
    signature = await addr1.signMessage(ethers.toBeArray(message));

    await expect(
      votingManager.connect(addr1).delistAsset(assetType, contractAddress, chainId, signature)
    ).to.emit(votingManager, "AssetDelisted");

    expect(await assetManager.isAssetListed(assetType, contractAddress, chainId)).to.be.false;
  });

  it("Should revert if non-current submitter tries to delist an asset", async function () {
    // List the asset first
    await votingManager
      .connect(addr1)
      .listAsset(assetName, nuDexName, assetType, contractAddress, chainId, signature);

    // set the address to non-current submitter
    await participantManager.setParticipant(
      await votingManager.lastSubmitterIndex(),
      ethers.ZeroAddress
    );
    const rawMessage = ethers.solidityPacked(
      ["uint8", "address", "uint"],
      [assetType, contractAddress, chainId]
    );
    const message = ethers.solidityPackedKeccak256(
      ["string", "bytes"],
      [((rawMessage.length - 2) / 2).toString(), rawMessage]
    );
    signature = await addr1.signMessage(ethers.toBeArray(message));
    await expect(
      votingManager.connect(addr1).delistAsset(assetType, contractAddress, chainId, "0x")
    ).to.be.revertedWith("Not the current submitter");
  });

  it("Should revert if signature verification fails when listing an asset", async function () {
    signature = signature.replace("1", "2"); // create a invalid signature
    await expect(
      votingManager.connect(addr1).listAsset(
        assetName,
        nuDexName,
        assetType,
        contractAddress,
        chainId,
        signature // invalid signature
      )
    ).to.be.revertedWith("Invalid signature");
  });

  it("Should revert if signature verification fails when delisting an asset", async function () {
    // List the asset first
    await votingManager
      .connect(addr1)
      .listAsset(assetName, nuDexName, assetType, contractAddress, chainId, signature);

    await participantManager.setParticipant(await votingManager.lastSubmitterIndex(), address1);
    const rawMessage = ethers.solidityPacked(
      ["uint8", "address", "uint"],
      [assetType, contractAddress, chainId]
    );
    const message = ethers.solidityPackedKeccak256(
      ["string", "bytes"],
      [((rawMessage.length - 2) / 2).toString(), rawMessage]
    );
    signature = await addr1.signMessage(ethers.toBeArray(message));
    signature = signature.replace("1", "2"); // create a invalid signature
    await expect(
      votingManager.connect(addr1).delistAsset(assetType, contractAddress, chainId, signature)
    ).to.be.revertedWith("Invalid signature");
  });
});
