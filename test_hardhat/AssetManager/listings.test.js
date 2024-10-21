const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AssetManager - Listing Assets", function () {
  let assetManager, owner, addr1, address1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    address1 = await addr1.getAddress();
    // Deploy AssetManager
    const AssetManager = await ethers.getContractFactory("AssetManager");
    assetManager = await AssetManager.deploy();
    await assetManager.waitForDeployment();
  });

  it("Should allow listing a new asset", async function () {
    const assetType = 2; // ERC20
    const assetName = "TestAsset";
    const nuDexName = "TST";
    const contractAddress = address1;
    const chainId = 1;

    await expect(
      assetManager.listAsset(assetName, nuDexName, assetType, contractAddress, chainId)
    ).to.emit(assetManager, "AssetListed");

    const assetId = await assetManager.getAssetIdentifier(assetType, contractAddress, chainId);
    const assetDetails = await assetManager.getAssetDetails(assetId);

    expect(assetDetails.name).to.equal(assetName);
    expect(assetDetails.nuDexName).to.equal(nuDexName);
    expect(assetDetails.assetType).to.equal(assetType);
    expect(assetDetails.contractAddress).to.equal(contractAddress);
    expect(assetDetails.chainId).to.equal(chainId);
    expect(assetDetails.isListed).to.be.true;
  });

  it("Should revert if trying to list an already listed asset", async function () {
    const assetType = 2; // ERC20
    const assetName = "TestAsset";
    const nuDexName = "TST";
    const contractAddress = address1;
    const chainId = 1;

    await assetManager.listAsset(assetName, nuDexName, assetType, contractAddress, chainId);

    await expect(
      assetManager.listAsset(assetName, nuDexName, assetType, contractAddress, chainId)
    ).to.be.revertedWith("Asset already listed");
  });

  it("Should allow listing multiple assets", async function () {
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

    const assetId1 = await assetManager.getAssetIdentifier(assetType1, contractAddress1, chainId1);
    const assetId2 = await assetManager.getAssetIdentifier(assetType2, contractAddress2, chainId2);

    const assetDetails1 = await assetManager.getAssetDetails(assetId1);
    const assetDetails2 = await assetManager.getAssetDetails(assetId2);

    expect(assetDetails1.name).to.equal(assetName1);
    expect(assetDetails2.name).to.equal(assetName2);
  });
});
