// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

enum AssetType {
    BTC,
    EVM,
    Ordinal,
    Inscription
}

struct AssetParam {
    AssetType assetType; // Type of the asset (BTC, EVM, Ordinal, Inscription)
    uint8 decimals;
    bool depositEnabled;
    bool withdrawalEnabled;
    uint256 withdrawFee;
    uint256 minDepositAmount;
    uint256 minWithdrawAmount;
    string assetAlias; // Common name of the asset
    string assetLogo;
}

struct NudexAsset {
    uint32 listIndex;
    AssetType assetType; // Type of the asset (BTC, EVM, Ordinal, Inscription)
    uint8 decimals;
    bool depositEnabled;
    bool withdrawalEnabled;
    bool isListed; // Whether the asset is listed
    uint32 createdTime;
    uint32 updatedTime;
    uint256 withdrawFee; // FIXME: put this inside TokenInfo?
    uint256 minDepositAmount;
    uint256 minWithdrawAmount;
    string assetAlias; // Common name of the asset
    string assetLogo;
}

struct TokenInfo {
    uint256 chainId; // Chain ID for EVM-based assets, or specific IDs for BTC/Ordinal
    bool isActive;
    AssetType assetType; // Type of the asset (BTC, EVM, Ordinal, Inscription)
    uint8 decimals;
    address contractAddress; // Address for ERC20, Inscription, or 0x0 for BTC/Ordinal/Native token
    string symbol;
    uint256 balance; // The balance of deposited token
    uint256 btcCount; // BTC count
}

interface IAssetHandler {
    // events
    event AssetListed(bytes32 indexed ticker, AssetParam assetParam);
    event AssetUpdated(bytes32 indexed ticker, AssetParam assetParam);
    event AssetDelisted(bytes32 indexed assetId);
    event Deposit(bytes32 indexed assetId, uint256 indexed assetIndex, uint256 indexed amount);
    event Withdraw(bytes32 indexed assetId, uint256 indexed assetIndex, uint256 indexed amount);

    // errors
    error InsufficientBalance(bytes32 assetId, uint256 assetIndex);
    error AssetNotListed(bytes32 ticker);

    // Check if an asset is listed
    function isAssetListed(bytes32 _ticker) external view returns (bool);

    // Get the details of an asset
    function getAssetDetails(bytes32 _ticker) external view returns (NudexAsset memory);

    // Get the list of all listed assets
    function getAllAssets() external view returns (bytes32[] memory);

    function withdraw(bytes32 _ticker, uint256 _chainId, uint256 _amount) external;
}
