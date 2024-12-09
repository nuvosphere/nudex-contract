// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAssetHandler, AssetType} from "../interfaces/IAssetHandler.sol";

contract AssetHandlerUpgradeable is IAssetHandler, OwnableUpgradeable {
    // Mapping from asset identifiers to their details
    mapping(bytes32 ticker => NudexAsset) public nudexAssets;
    mapping(bytes32 ticker => mapping(uint256 chainId => OnchainAsset)) public onchainAsset;
    mapping(bytes32 ticker => mapping(bytes32 addr => uint256 bal)) public balances;
    // Array of asset identifiers
    bytes32[] public assetList;

    // _owner: EntryPoint contract
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    // Check if an asset is listed
    function isAssetListed(bytes32 _ticker) external view returns (bool) {
        return nudexAssets[_ticker].isListed;
    }

    // Get the details of an asset
    function getAssetDetails(bytes32 assetId) external view returns (NudexAsset memory) {
        require(nudexAssets[assetId].isListed, "Asset not listed");
        return nudexAssets[assetId];
    }

    // Get the list of all listed assets
    function getAllAssets() external view returns (bytes32[] memory) {
        return assetList;
    }

    // List a new asset on the specified chain
    function listAsset(bytes32 _ticker, NudexAsset calldata _newAsset) external onlyOwner {
        require(!nudexAssets[_ticker].isListed, "Asset already listed");
        nudexAssets[_ticker] = _newAsset;
        assetList.push(_ticker);

        emit AssetListed(_ticker, _newAsset);
    }

    // Delist an existing asset
    function delistAsset(bytes32 _ticker) external onlyOwner {
        require(nudexAssets[_ticker].isListed, "Asset not listed");
        nudexAssets[_ticker].isListed = false;
        emit AssetDelisted(_ticker);
    }

    function deposit(
        bytes32 _ticker,
        AssetType _assetType,
        address _contractAddress,
        uint256 _chainId,
        bytes32 _address,
        uint256 _amount
    ) external onlyOwner {
        onchainAsset[_ticker][_chainId].balance += _amount;
        emit Deposit(_ticker, _address, _amount);
    }

    function withdraw(
        bytes32 _ticker,
        AssetType _assetType,
        address _contractAddress,
        uint256 _chainId,
        bytes32 _address,
        uint256 _amount
    ) external onlyOwner {
        require(
            onchainAsset[_ticker][_chainId].balance >= _amount,
            InsufficientBalance(_ticker, _address)
        );
        onchainAsset[_ticker][_chainId].balance -= _amount;
        emit Deposit(_ticker, _address, _amount);
    }
}
