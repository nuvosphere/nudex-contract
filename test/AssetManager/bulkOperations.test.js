const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AssetManager - Bulk Operations", function () {
  let assetManager, owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    // Deploy AssetManager
    const AssetManager = await ethers.getContractFactory("AssetManager");
    assetManager = await AssetManager.deploy();
    await assetManager.deployed();
  });

  it("Should allow listing multiple assets in bulk", async function () {
    const assets = [
      { name: "Asset1", nuDexName: "AS1", assetType: 2, contractAddress: addr1.address, chainId: 1 },
      { name: "Asset2", nuDexName: "AS2", assetType: 2, contractAddress: addr2.address, chainId: 1 },
      { name: "Asset3", nuDexName: "AS3", assetType: 3, contractAddress: addr1.address, chainId: 2 },
    ];

    for (const asset of assets) {
      await assetManager.listAsset(asset.name, asset.nuDexName, asset.assetType, asset.contractAddress, asset.chainId);
    }

    for (const asset of assets) {
      const assetId = await assetManager.getAssetIdentifier(asset.assetType, asset.contractAddress, asset.chainId);
      const assetDetails = await assetManager.getAssetDetails(assetId);

      expect(assetDetails.name).to.equal(asset.name);
      expect(assetDetails.nuDexName).to.equal(asset.nuDexName);
      expect(assetDetails.assetType).to.equal(asset.assetType);
      expect(assetDetails.contractAddress).to.equal(asset.contractAddress);
      expect(assetDetails.chainId).to.equal(asset.chainId);
      expect(assetDetails.isListed).to.be.true;
    }
  });

  it("Should allow delisting multiple assets in bulk", async function () {
    const assets = [
      { name: "Asset1", nuDexName: "AS1", assetType: 2, contractAddress: addr1.address, chainId: 1 },
      { name: "Asset2", nuDexName: "AS2", assetType: 2, contractAddress: addr2.address, chainId: 1 },
      { name: "Asset3", nuDexName: "AS3", assetType: 3, contractAddress: addr1.address, chainId: 2 },
    ];

    // List all assets first
    for (const asset of assets) {
      await assetManager.listAsset(asset.name, asset.nuDexName, asset.assetType, asset.contractAddress, asset.chainId);
    }

    // Delist all assets
    for (const asset of assets) {
      await assetManager.delistAsset(asset.assetType, asset.contractAddress, asset.chainId);
    }

    for (const asset of assets) {
      const assetId = await assetManager.getAssetIdentifier(asset.assetType, asset.contractAddress, asset.chainId);
      const assetDetails = await assetManager.getAssetDetails(assetId);

      expect(assetDetails.isListed).to.be.false;
    }
  });

  it("Should revert if trying to delist an asset that was not listed", async function () {
    const assetType = 2; // ERC20
    const contractAddress = addr1.address;
    const chainId = 1;

    await expect(assetManager.delistAsset(assetType, contractAddress, chainId))
      .to.be.revertedWith("Asset not listed");
  });

  it("Should correctly handle listing and delisting the same asset multiple times", async function () {
    const assetType = 2; // ERC20
    const assetName = "Asset1";
    const nuDexName = "AS1";
    const contractAddress = addr1.address;
    const chainId = 1;

    await assetManager.listAsset(assetName, nuDexName, assetType, contractAddress, chainId);
    await assetManager.delistAsset(assetType, contractAddress, chainId);

    // Attempt to relist the same asset
    await assetManager.listAsset(assetName, nuDexName, assetType, contractAddress, chainId);
    
    const assetId = await assetManager.getAssetIdentifier(assetType, contractAddress, chainId);
    const assetDetails = await assetManager.getAssetDetails(assetId);

    expect(assetDetails.isListed).to.be.true;
  });
});
