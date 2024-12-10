// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAssetHandler, AssetParam, AssetType, NudexAsset, TokenInfo} from "../interfaces/IAssetHandler.sol";

contract AssetHandlerUpgradeable is IAssetHandler, OwnableUpgradeable {
    NudexAsset[] public nudexAssets;
    mapping(bytes32 ticker => uint256 assetIndex) public nudexAssetIndexes;
    mapping(bytes32 ticker => TokenInfo[]) public linkedTokens;
    mapping(uint32 tokenId => uint256 tokenIndex) public linkedTokenIndexes;

    uint32 public assetIdCounter;

    modifier requireListing(bytes32 _ticker) {
        require(nudexAssets[nudexAssetIndexes[_ticker]].isListed, AssetNotListed(_ticker));
        _;
    }

    // _owner: EntryPoint contract
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    // Check if an asset is listed
    function isAssetListed(bytes32 _ticker) external view returns (bool) {
        return nudexAssets[nudexAssetIndexes[_ticker]].isListed;
    }

    // Get the details of an asset
    function getAssetDetails(
        bytes32 _ticker
    ) external view requireListing(_ticker) returns (NudexAsset memory) {
        return nudexAssets[nudexAssetIndexes[_ticker]];
    }

    // Get the list of all listed assets
    function getAllAssets() external view returns (NudexAsset[] memory) {
        return nudexAssets;
    }

    // List a new asset
    function listNewAsset(bytes32 _ticker, AssetParam calldata _assetParam) external onlyOwner {
        require(nudexAssetIndexes[_ticker] == 0, "Asset already listed");
        NudexAsset memory newNudexAsset;
        // update listed assets
        newNudexAsset.id = assetIdCounter++;
        newNudexAsset.isListed = true;
        newNudexAsset.createdTime = uint32(block.timestamp);
        newNudexAsset.updatedTime = uint32(block.timestamp);

        // info from param
        newNudexAsset.assetType = _assetParam.assetType;
        newNudexAsset.decimals = _assetParam.decimals;
        newNudexAsset.depositEnabled = _assetParam.depositEnabled;
        newNudexAsset.withdrawalEnabled = _assetParam.withdrawalEnabled;
        newNudexAsset.withdrawFee = _assetParam.withdrawFee;
        newNudexAsset.minDepositAmount = _assetParam.minDepositAmount;
        newNudexAsset.minWithdrawAmount = _assetParam.minWithdrawAmount;
        newNudexAsset.assetAlias = _assetParam.assetAlias;
        newNudexAsset.assetLogo = _assetParam.assetLogo;

        nudexAssets.push(newNudexAsset);
        emit AssetListed(_ticker, _assetParam);
    }

    // Update listed asset
    function updateAsset(
        bytes32 _ticker,
        AssetParam calldata _assetParam
    ) external onlyOwner requireListing(_ticker) {
        NudexAsset storage nudexAsset = nudexAssets[nudexAssetIndexes[_ticker]];
        // update listed assets
        nudexAsset.updatedTime = uint32(block.timestamp);

        // info from param
        nudexAsset.assetType = _assetParam.assetType;
        nudexAsset.decimals = _assetParam.decimals;
        nudexAsset.depositEnabled = _assetParam.depositEnabled;
        nudexAsset.withdrawalEnabled = _assetParam.withdrawalEnabled;
        nudexAsset.withdrawFee = _assetParam.withdrawFee;
        nudexAsset.minDepositAmount = _assetParam.minDepositAmount;
        nudexAsset.minWithdrawAmount = _assetParam.minWithdrawAmount;
        nudexAsset.assetAlias = _assetParam.assetAlias;
        nudexAsset.assetLogo = _assetParam.assetLogo;

        emit AssetUpdated(_ticker, _assetParam);
    }

    // Delist an existing asset
    function delistAsset(bytes32 _ticker) external onlyOwner requireListing(_ticker) {
        nudexAssets[nudexAssetIndexes[_ticker]].isListed = false;
        nudexAssets[nudexAssetIndexes[_ticker]].updatedTime = uint32(block.timestamp);
        emit AssetDelisted(_ticker);
    }

    function linkToken(
        bytes32 _ticker,
        TokenInfo[] calldata _tokenInfos
    ) external onlyOwner requireListing(_ticker) {
        for (uint8 i; i < _tokenInfos.length; ++i) {
            linkedTokens[_ticker].push(_tokenInfos[i]);
        }
    }

    function unlinkToken(
        bytes32 _ticker,
        uint32[] calldata _tokenIds
    ) external onlyOwner requireListing(_ticker) {
        TokenInfo[] storage tokenInfos = linkedTokens[_ticker];
        for (uint8 i; i < _tokenIds.length; ++i) {
            linkedTokenIndexes[tokenInfos[tokenInfos.length - 1].id] = linkedTokenIndexes[
                _tokenIds[i]
            ];
            tokenInfos[linkedTokenIndexes[_tokenIds[i]]] = tokenInfos[tokenInfos.length - 1];
            linkedTokenIndexes[_tokenIds[i]] = 0;
            tokenInfos.pop();
        }
    }

    function deposit(
        bytes32 _ticker,
        uint256 _tokenInfoIndex,
        uint256 _amount
    ) external onlyOwner requireListing(_ticker) {
        linkedTokens[_ticker][_tokenInfoIndex].balance += _amount;
        emit Deposit(_ticker, _tokenInfoIndex, _amount);
    }

    function withdraw(
        bytes32 _ticker,
        uint256 _tokenInfoIndex,
        uint256 _amount
    ) external onlyOwner requireListing(_ticker) {
        require(
            linkedTokens[_ticker][_tokenInfoIndex].balance >= _amount,
            InsufficientBalance(_ticker, _tokenInfoIndex)
        );
        linkedTokens[_ticker][_tokenInfoIndex].balance -= _amount;
        emit Deposit(_ticker, _tokenInfoIndex, _amount);
    }
}
