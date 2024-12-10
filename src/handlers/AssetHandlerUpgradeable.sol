// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAssetHandler, AssetParam, AssetType, NudexAsset, TokenInfo} from "../interfaces/IAssetHandler.sol";

contract AssetHandlerUpgradeable is IAssetHandler, OwnableUpgradeable {
    // Mapping from asset identifiers to their details
    bytes32[] public nudexAssetList;
    mapping(bytes32 ticker => NudexAsset) public nudexAssets;
    mapping(bytes32 ticker => TokenInfo[]) public linkedTokens;
    mapping(uint32 tokenId => uint256 index) public linkedTokenIndexes;

    // Array of listed asset tickers

    uint32 public idCounter;

    modifier requireListing(bytes32 _ticker) {
        require(nudexAssets[_ticker].isListed, AssetNotListed(_ticker));
        _;
    }

    // _owner: EntryPoint contract
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    // Check if an asset is listed
    function isAssetListed(bytes32 _ticker) external view returns (bool) {
        return nudexAssets[_ticker].isListed;
    }

    // Get the details of an asset
    function getAssetDetails(
        bytes32 _ticker
    ) external view requireListing(_ticker) returns (NudexAsset memory) {
        return nudexAssets[_ticker];
    }

    // Get the list of all listed assets
    function getAllAssets() external view returns (bytes32[] memory) {
        return nudexAssetList;
    }

    // List a new asset
    function listNewAsset(bytes32 _ticker, AssetParam calldata _assetParam) external onlyOwner {
        require(!nudexAssets[_ticker].isListed, "Asset already listed");
        // update listed assets
        nudexAssets[_ticker].id = idCounter++;
        nudexAssets[_ticker].isListed = true;
        nudexAssets[_ticker].createdTime = uint32(block.timestamp);
        nudexAssets[_ticker].updatedTime = uint32(block.timestamp);

        // info from param
        nudexAssets[_ticker].assetType = _assetParam.assetType;
        nudexAssets[_ticker].decimals = _assetParam.decimals;
        nudexAssets[_ticker].depositEnabled = _assetParam.depositEnabled;
        nudexAssets[_ticker].withdrawalEnabled = _assetParam.withdrawalEnabled;
        nudexAssets[_ticker].withdrawFee = _assetParam.withdrawFee;
        nudexAssets[_ticker].minDepositAmount = _assetParam.minDepositAmount;
        nudexAssets[_ticker].minWithdrawAmount = _assetParam.minWithdrawAmount;
        nudexAssets[_ticker].assetAlias = _assetParam.assetAlias;
        nudexAssets[_ticker].assetLogo = _assetParam.assetLogo;

        nudexAssetList.push(_ticker);
        emit AssetListed(_ticker, _assetParam);
    }

    // Update listed asset
    function updateAsset(
        bytes32 _ticker,
        AssetParam calldata _assetParam
    ) external onlyOwner requireListing(_ticker) {
        // update listed assets
        nudexAssets[_ticker].updatedTime = uint32(block.timestamp);

        // info from param
        nudexAssets[_ticker].assetType = _assetParam.assetType;
        nudexAssets[_ticker].decimals = _assetParam.decimals;
        nudexAssets[_ticker].depositEnabled = _assetParam.depositEnabled;
        nudexAssets[_ticker].withdrawalEnabled = _assetParam.withdrawalEnabled;
        nudexAssets[_ticker].withdrawFee = _assetParam.withdrawFee;
        nudexAssets[_ticker].minDepositAmount = _assetParam.minDepositAmount;
        nudexAssets[_ticker].minWithdrawAmount = _assetParam.minWithdrawAmount;
        nudexAssets[_ticker].assetAlias = _assetParam.assetAlias;
        nudexAssets[_ticker].assetLogo = _assetParam.assetLogo;

        emit AssetUpdated(_ticker, _assetParam);
    }

    // Delist an existing asset
    function delistAsset(bytes32 _ticker) external onlyOwner requireListing(_ticker) {
        nudexAssets[_ticker].isListed = false;
        nudexAssets[_ticker].updatedTime = uint32(block.timestamp);
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
