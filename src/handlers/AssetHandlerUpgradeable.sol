// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAssetHandler, AssetType, NudexAsset, OnchainAsset} from "../interfaces/IAssetHandler.sol";

contract AssetHandlerUpgradeable is IAssetHandler, OwnableUpgradeable {
    // Mapping from asset identifiers to their details
    mapping(bytes32 ticker => NudexAsset) public nudexAssets;
    mapping(bytes32 ticker => OnchainAsset[]) public onchainAssets;

    // Array of asset identifiers
    bytes32[] public nudexAssetList;
    mapping(bytes32 ticker => uint256 index) public nudexAssetListIndex;

    // _owner: EntryPoint contract
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    // Check if an asset is listed
    function isAssetListed(bytes32 _ticker) external view returns (bool) {
        return nudexAssets[_ticker].isListed;
    }

    // Get the details of an asset
    function getAssetDetails(bytes32 _ticker) external view returns (NudexAsset memory) {
        require(nudexAssets[_ticker].isListed, "Asset not listed");
        return nudexAssets[_ticker];
    }

    // Get the list of all listed assets
    function getAllAssets() external view returns (bytes32[] memory) {
        return nudexAssetList;
    }

    // List a new asset on the specified chain
    function listAsset(bytes32 _ticker, NudexAsset calldata _newAsset) external onlyOwner {
        require(!nudexAssets[_ticker].isListed, "Asset already listed");
        nudexAssets[_ticker] = _newAsset;
        // update listed assets
        nudexAssetListIndex[_ticker] = nudexAssetList.length;
        nudexAssetList.push(_ticker);

        emit AssetListed(_ticker, _newAsset);
    }

    // Delist an existing asset
    function delistAsset(bytes32 _ticker) external onlyOwner {
        require(nudexAssets[_ticker].isListed, "Asset not listed");
        nudexAssets[_ticker].isListed = false;
        emit AssetDelisted(_ticker);
    }

    function linkAsset(
        bytes32 _ticker,
        OnchainAsset calldata _onchainAsset,
        bool _depositable,
        bool _withdrawable
    ) external onlyOwner {
        require(nudexAssets[_ticker].isListed, "Asset not listed");
        if (_depositable) {
            nudexAssets[_ticker].depositChainIds.push(_onchainAsset.chainId);
        }
        if (_withdrawable) {
            nudexAssets[_ticker].withdrawalChainIds.push(_onchainAsset.chainId);
        }
        onchainAssets[_ticker].push(_onchainAsset);
    }

    function deposit(
        bytes32 _ticker,
        uint256 _onchainAssetIndex,
        uint256 _amount
    ) external onlyOwner {
        require(nudexAssets[_ticker].isListed, "Asset not listed");
        onchainAssets[_ticker][_onchainAssetIndex].balance += _amount;
        emit Deposit(_ticker, _onchainAssetIndex, _amount);
    }

    function withdraw(
        bytes32 _ticker,
        uint256 _onchainAssetIndex,
        uint256 _amount
    ) external onlyOwner {
        require(nudexAssets[_ticker].isListed, "Asset not listed");
        require(
            onchainAssets[_ticker][_onchainAssetIndex].balance >= _amount,
            InsufficientBalance(_ticker, _onchainAssetIndex)
        );
        onchainAssets[_ticker][_onchainAssetIndex].balance -= _amount;
        emit Deposit(_ticker, _onchainAssetIndex, _amount);
    }
}
