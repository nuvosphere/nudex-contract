// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract MockAssetManager {
    struct Asset {
        string name;
        string nuDexName;
        uint8 assetType;
        address contractAddress;
        uint256 chainId;
        bool isListed;
    }

    mapping(bytes32 => Asset) public assets;

    function listAsset(
        string memory name,
        string memory nuDexName,
        uint8 assetType,
        address contractAddress,
        uint256 chainId
    ) external {
        bytes32 assetId = getAssetIdentifier(assetType, contractAddress, chainId);
        assets[assetId] = Asset({
            name: name,
            nuDexName: nuDexName,
            assetType: assetType,
            contractAddress: contractAddress,
            chainId: chainId,
            isListed: true
        });
    }

    function delistAsset(uint8 assetType, address contractAddress, uint256 chainId) external {
        bytes32 assetId = getAssetIdentifier(assetType, contractAddress, chainId);
        assets[assetId].isListed = false;
    }

    function isAssetListed(
        uint8 assetType,
        address contractAddress,
        uint256 chainId
    ) external view returns (bool) {
        bytes32 assetId = getAssetIdentifier(assetType, contractAddress, chainId);
        return assets[assetId].isListed;
    }

    function getAssetIdentifier(
        uint8 assetType,
        address contractAddress,
        uint256 chainId
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(assetType, contractAddress, chainId));
    }
}
