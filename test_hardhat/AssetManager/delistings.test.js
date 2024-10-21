const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AssetManager - Delisting Assets", function () {
  let assetManager, owner, addr1, address1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    address1 = await addr1.getAddress();

    // Deploy AssetManager
    const AssetManager = await ethers.getContractFactory("AssetManager");
    assetManager = await AssetManager.deploy();
    await assetManager.waitForDeployment();

    // List an asset to be delisted later
    const assetType = 2; // ERC20
    const assetName = "TestAsset";
    const nuDexName = "TST";
    const contractAddress = address1;
    const chainId = 1;

    await assetManager.listAsset(assetName, nuDexName, assetType, contractAddress, chainId);
  });

  it("Should allow delisting an asset", async function () {
    const assetType = 2; // ERC20
    const contractAddress = address1;
    const chainId = 1;

    await expect(assetManager.delistAsset(assetType, contractAddress, chainId)).to.emit(
      assetManager,
      "AssetDelisted"
    );

    const assetId = await assetManager.getAssetIdentifier(assetType, contractAddress, chainId);
    await expect(assetManager.getAssetDetails(assetId)).to.be.rejectedWith("Asset not listed");
  });

  it("Should revert if trying to delist an asset that is not listed", async function () {
    const assetType = 2; // ERC20
    const contractAddress = address1;
    const chainId = 1;

    // Delist the asset first
    await assetManager.delistAsset(assetType, contractAddress, chainId);

    // Attempt to delist the same asset again
    await expect(assetManager.delistAsset(assetType, contractAddress, chainId)).to.be.revertedWith(
      "Asset not listed"
    );
  });

  it("Should correctly handle multiple assets being delisted", async function () {
    const assetType1 = 2; // ERC20
    const contractAddress1 = address1;
    const chainId1 = 1;

    const assetType2 = 3; // Another type (e.g., Ordinals)
    const contractAddress2 = await owner.getAddress();
    const chainId2 = 1;

    // List a second asset
    await assetManager.listAsset("TestAsset2", "TST2", assetType2, contractAddress2, chainId2);

    // Delist both assets
    await assetManager.delistAsset(assetType1, contractAddress1, chainId1);
    await assetManager.delistAsset(assetType2, contractAddress2, chainId2);

    const assetId1 = await assetManager.getAssetIdentifier(assetType1, contractAddress1, chainId1);
    const assetId2 = await assetManager.getAssetIdentifier(assetType2, contractAddress2, chainId2);

    await expect(assetManager.getAssetDetails(assetId1)).to.be.rejectedWith("Asset not listed");
    await expect(assetManager.getAssetDetails(assetId2)).to.be.rejectedWith("Asset not listed");
  });
});
