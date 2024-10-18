const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AssetManager - Retrieving Asset Details", function () {
  let assetManager, owner, addr1, address1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    address1 = await addr1.getAddress();

    // Deploy AssetManager
    const AssetManager = await ethers.getContractFactory("AssetManager");
    assetManager = await AssetManager.deploy();
    await assetManager.waitForDeployment();

    // List some assets to retrieve later
    const assetType1 = 2; // ERC20
    const assetName1 = "TestAsset1";
    const nuDexName1 = "TST1";
    const contractAddress1 = address1;
    const chainId1 = 1;

    const assetType2 = 3; // Another type (e.g., Ordinals)
    const assetName2 = "TestAsset2";
    const nuDexName2 = "TST2";
    const contractAddress2 = await owner.getAddress();
    const chainId2 = 1;

    await assetManager.listAsset(assetName1, nuDexName1, assetType1, contractAddress1, chainId1);
    await assetManager.listAsset(assetName2, nuDexName2, assetType2, contractAddress2, chainId2);
  });

  it("Should retrieve correct details for a listed asset", async function () {
    const assetType = 2; // ERC20
    const contractAddress = address1;
    const chainId = 1;

    const assetId = await assetManager.getAssetIdentifier(assetType, contractAddress, chainId);
    const assetDetails = await assetManager.getAssetDetails(assetId);

    expect(assetDetails.name).to.equal("TestAsset1");
    expect(assetDetails.nuDexName).to.equal("TST1");
    expect(assetDetails.assetType).to.equal(assetType);
    expect(assetDetails.contractAddress).to.equal(contractAddress);
    expect(assetDetails.chainId).to.equal(chainId);
    expect(assetDetails.isListed).to.be.true;
  });

  it("Should revert if trying to retrieve details for an unlisted asset", async function () {
    const assetType = 2; // ERC20
    const contractAddress = address1;
    const chainId = 1;

    // Delist the asset first
    await assetManager.delistAsset(assetType, contractAddress, chainId);

    const assetId = await assetManager.getAssetIdentifier(assetType, contractAddress, chainId);
    await expect(assetManager.getAssetDetails(assetId)).to.be.revertedWith("Asset not listed");
  });

  it("Should correctly retrieve details for multiple assets", async function () {
    const assetType1 = 2; // ERC20
    const contractAddress1 = address1;
    const chainId1 = 1;

    const assetType2 = 3; // Another type (e.g., Ordinals)
    const contractAddress2 = await owner.getAddress();
    const chainId2 = 1;

    const assetId1 = await assetManager.getAssetIdentifier(assetType1, contractAddress1, chainId1);
    const assetId2 = await assetManager.getAssetIdentifier(assetType2, contractAddress2, chainId2);

    const assetDetails1 = await assetManager.getAssetDetails(assetId1);
    const assetDetails2 = await assetManager.getAssetDetails(assetId2);

    expect(assetDetails1.name).to.equal("TestAsset1");
    expect(assetDetails2.name).to.equal("TestAsset2");
    expect(assetDetails1.nuDexName).to.equal("TST1");
    expect(assetDetails2.nuDexName).to.equal("TST2");
  });
});
