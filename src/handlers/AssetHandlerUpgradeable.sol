// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAssetHandler} from "../interfaces/IAssetHandler.sol";

contract AssetHandlerUpgradeable is IAssetHandler, OwnableUpgradeable {
    // Mapping from asset identifiers to their details
    mapping(bytes32 id => Asset) public assets;
    mapping(bytes32 id => mapping(bytes32 addr => uint256 bal)) public balances;
    // Array of asset identifiers
    bytes32[] public assetList;

    // _owner: EntryPoint contract
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    // Create a unique identifier for an asset based on its type, address, and chain ID
    function getAssetIdentifier(
        AssetType _assetType,
        address _contractAddress,
        uint256 _chainId
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_assetType, _contractAddress, _chainId));
    }

    // Check if an asset is listed
    function isAssetListed(
        AssetType _assetType,
        address _contractAddress,
        uint256 _chainId
    ) external view returns (bool) {
        return assets[getAssetIdentifier(_assetType, _contractAddress, _chainId)].isListed;
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

    // List a new asset on the specified chain
    function listAsset(
        string memory _name,
        string memory _nuDexName,
        AssetType _assetType,
        address _contractAddress,
        uint256 _chainId
    ) external onlyOwner {
        bytes32 assetId = getAssetIdentifier(_assetType, _contractAddress, _chainId);
        require(!assets[assetId].isListed, "Asset already listed");

        Asset memory newAsset = Asset({
            name: _name,
            nuDexName: _nuDexName,
            assetType: _assetType,
            contractAddress: _contractAddress,
            chainId: _chainId,
            isListed: true
        });

        assets[assetId] = newAsset;
        assetList.push(assetId);

        emit AssetListed(assetId, _name, _nuDexName, _assetType, _contractAddress, _chainId);
    }

    // Delist an existing asset
    function delistAsset(
        AssetType _assetType,
        address _contractAddress,
        uint256 _chainId
    ) external onlyOwner {
        bytes32 assetId = getAssetIdentifier(_assetType, _contractAddress, _chainId);
        require(assets[assetId].isListed, "Asset not listed");

        assets[assetId].isListed = false;

        emit AssetDelisted(assetId);
    }

    function deposit(
        AssetType _assetType,
        address _contractAddress,
        uint256 _chainId,
        bytes32 _address,
        uint256 _amount
    ) external onlyOwner {
        bytes32 assetId = getAssetIdentifier(_assetType, _contractAddress, _chainId);
        balances[assetId][_address] += _amount;
        emit Deposit(assetId, _address, _amount);
    }

    function withdraw(
        AssetType _assetType,
        address _contractAddress,
        uint256 _chainId,
        bytes32 _address,
        uint256 _amount
    ) external onlyOwner {
        bytes32 assetId = getAssetIdentifier(_assetType, _contractAddress, _chainId);
        require(balances[assetId][_address] >= _amount, InsufficientBalance(assetId, _address));
        balances[assetId][_address] -= _amount;
        emit Deposit(assetId, _address, _amount);
    }
}
