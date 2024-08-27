const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AssetManager - Delisting Assets", function () {
  let assetManager, owner, addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();

    // Deploy AssetManager
    const AssetManager = await ethers.getContractFactory("AssetManager");
    assetManager = await AssetManager.deploy();
    await assetManager.deployed();

    // List an asset to be delisted later
    const assetType = 2; // ERC20
    const assetName = "TestAsset";
    const nuDexName = "TST";
    const contractAddress = addr1.address;
    const chainId = 1;

    await assetManager.listAsset(assetName, nuDexName, assetType, contractAddress, chainId);
  });

  it("Should allow delisting an asset", async function () {
    const assetType = 2; // ERC20
    const contractAddress = addr1.address;
    const chainId = 1;

    await expect(assetManager.delistAsset(assetType, contractAddress, chainId))
      .to.emit(assetManager, "AssetDelisted");

    const assetId = await assetManager.getAssetIdentifier(assetType, contractAddress, chainId);
    const assetDetails = await assetManager.getAssetDetails(assetId);

    expect(assetDetails.isListed).to.be.false;
  });

  it("Should revert if trying to delist an asset that is not listed", async function () {
    const assetType = 2; // ERC20
    const contractAddress = addr1.address;
    const chainId = 1;

    // Delist the asset first
    await assetManager.delistAsset(assetType, contractAddress, chainId);

    // Attempt to delist the same asset again
    await expect(assetManager.delistAsset(assetType, contractAddress, chainId))
      .to.be.revertedWith("Asset not listed");
  });

  it("Should correctly handle multiple assets being delisted", async function () {
    const assetType1 = 2; // ERC20
    const contractAddress1 = addr1.address;
    const chainId1 = 1;

    const assetType2 = 3; // Another type (e.g., Ordinals)
    const contractAddress2 = owner.address;
    const chainId2 = 1;

    // List a second asset
    await assetManager.listAsset("TestAsset2", "TST2", assetType2, contractAddress2, chainId2);

    // Delist both assets
    await assetManager.delistAsset(assetType1, contractAddress1, chainId1);
    await assetManager.delistAsset(assetType2, contractAddress2, chainId2);

    const assetId1 = await assetManager.getAssetIdentifier(assetType1, contractAddress1, chainId1);
    const assetId2 = await assetManager.getAssetIdentifier(assetType2, contractAddress2, chainId2);

    const assetDetails1 = await assetManager.getAssetDetails(assetId1);
    const assetDetails2 = await assetManager.getAssetDetails(assetId2);

    expect(assetDetails1.isListed).to.be.false;
    expect(assetDetails2.isListed).to.be.false;
  });
});
