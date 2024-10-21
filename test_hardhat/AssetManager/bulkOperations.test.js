const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AssetManager - Bulk Operations", function () {
  let assetManager, owner, addr1, address1, addr2, address2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    address1 = await addr1.getAddress();
    address2 = await addr2.getAddress();

    // Deploy AssetManager
    const AssetManager = await ethers.getContractFactory("AssetManager");
    assetManager = await AssetManager.deploy();
    await assetManager.waitForDeployment();
  });

  it("Should allow listing multiple assets in bulk", async function () {
    const assets = [
      {
        name: "Asset1",
        nuDexName: "AS1",
        assetType: 2,
        contractAddress: address1,
        chainId: 1,
      },
      {
        name: "Asset2",
        nuDexName: "AS2",
        assetType: 2,
        contractAddress: address2,
        chainId: 1,
      },
      {
        name: "Asset3",
        nuDexName: "AS3",
        assetType: 3,
        contractAddress: address1,
        chainId: 2,
      },
    ];

    for (const asset of assets) {
      await assetManager.listAsset(
        asset.name,
        asset.nuDexName,
        asset.assetType,
        asset.contractAddress,
        asset.chainId
      );
    }

    for (const asset of assets) {
      const assetId = await assetManager.getAssetIdentifier(
        asset.assetType,
        asset.contractAddress,
        asset.chainId
      );
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
      {
        name: "Asset1",
        nuDexName: "AS1",
        assetType: 2,
        contractAddress: address1,
        chainId: 1,
      },
      {
        name: "Asset2",
        nuDexName: "AS2",
        assetType: 2,
        contractAddress: address2,
        chainId: 1,
      },
      {
        name: "Asset3",
        nuDexName: "AS3",
        assetType: 3,
        contractAddress: address1,
        chainId: 2,
      },
    ];

    // List all assets first
    for (const asset of assets) {
      await assetManager.listAsset(
        asset.name,
        asset.nuDexName,
        asset.assetType,
        asset.contractAddress,
        asset.chainId
      );
    }

    // Delist all assets
    for (const asset of assets) {
      await assetManager.delistAsset(asset.assetType, asset.contractAddress, asset.chainId);
    }

    for (const asset of assets) {
      const assetId = await assetManager.getAssetIdentifier(
        asset.assetType,
        asset.contractAddress,
        asset.chainId
      );
      await expect(assetManager.getAssetDetails(assetId)).to.be.rejectedWith("Asset not listed");
    }
  });

  it("Should revert if trying to delist an asset that was not listed", async function () {
    const assetType = 2; // ERC20
    const contractAddress = address1;
    const chainId = 1;

    await expect(assetManager.delistAsset(assetType, contractAddress, chainId)).to.be.revertedWith(
      "Asset not listed"
    );
  });

  it("Should correctly handle listing and delisting the same asset multiple times", async function () {
    const assetType = 2; // ERC20
    const assetName = "Asset1";
    const nuDexName = "AS1";
    const contractAddress = address1;
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
