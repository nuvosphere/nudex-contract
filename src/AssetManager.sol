// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IAssetManager.sol";

contract AssetManager is IAssetManager {
    
    // Mapping from asset identifiers to their details
    mapping(bytes32 => Asset) public assets;
    // Array of asset identifiers
    bytes32[] public assetList;

    // Create a unique identifier for an asset based on its type, address, and chain ID
    function getAssetIdentifier(AssetType assetType, address contractAddress, uint256 chainId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(assetType, contractAddress, chainId));
    }

    // List a new asset on the specified chain
    function listAsset(string memory name, string memory nuDexName, AssetType assetType, address contractAddress, uint256 chainId) external {
        bytes32 assetId = getAssetIdentifier(assetType, contractAddress, chainId);
        require(!assets[assetId].isListed, "Asset already listed");

        Asset memory newAsset = Asset({
            name: name,
            nuDexName: nuDexName,
            assetType: assetType,
            contractAddress: contractAddress,
            chainId: chainId,
            isListed: true
        });

        assets[assetId] = newAsset;
        assetList.push(assetId);

        emit AssetListed(assetId, name, nuDexName, assetType, contractAddress, chainId);
    }

    // Delist an existing asset
    function delistAsset(AssetType assetType, address contractAddress, uint256 chainId) external {
        bytes32 assetId = getAssetIdentifier(assetType, contractAddress, chainId);
        require(assets[assetId].isListed, "Asset not listed");

        assets[assetId].isListed = false;

        emit AssetDelisted(assetId);
    }

    // Check if an asset is listed
    function isAssetListed(AssetType assetType, address contractAddress, uint256 chainId) external view returns (bool) {
        bytes32 assetId = getAssetIdentifier(assetType, contractAddress, chainId);
        return assets[assetId].isListed;
    }

    // Get the details of an asset
    function getAssetDetails(bytes32 assetId) external view returns (Asset memory) {
        require(assets[assetId].isListed, "Asset not listed");
        return assets[assetId];
    }

    // Get the list of all listed assets
    function getAllAssets() external view returns (bytes32[] memory) {
        return assetList;
    }
}
