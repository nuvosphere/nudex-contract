// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

enum AssetType {
    BTC,
    EVM,
    Ordinal,
    Inscription
}

struct NudexAsset {
    uint256 id;
    string assetAlias; // Common name of the asset
    string assetLogo;
    AssetType assetType; // Type of the asset (BTC, EVM, Ordinal, Inscription)
    uint8 decimals;
    bool depositEnabled;
    bool withdrawalEnabled;
    bool isListed; // Whether the asset is listed
    uint32 createdTime;
    uint32 updatedTime;
    uint256 withdrawFee;
    uint256 minWithdrawAmount;
    uint256 minDepositAmount;
    uint256[] depositChainIds;
    uint256[] withdrawalChainIds;
}

struct OnchainAsset {
    uint256 id;
    uint256 chainId; // Chain ID for EVM-based assets, or specific IDs for BTC/Ordinal
    AssetType assetType; // Type of the asset (BTC, EVM, Ordinal, Inscription)
    address contractAddress; // Address for ERC20, Inscription, or 0x0 for BTC/Ordinal/Native token
    uint8 decimals;
    string symbol;
    bytes32 tokenAddr;
    uint256 balance;
}

interface IAssetHandler {
    // events
    event AssetListed(bytes32 indexed ticker, NudexAsset newAsset);
    event AssetDelisted(bytes32 indexed assetId);
    event Deposit(bytes32 indexed assetId, uint256 indexed assetIndex, uint256 indexed amount);
    event Withdraw(bytes32 indexed assetId, uint256 indexed assetIndex, uint256 indexed amount);

    // errors
    error InsufficientBalance(bytes32 assetId, uint256 assetIndex);

    // Check if an asset is listed
    function isAssetListed(bytes32 _ticker) external view returns (bool);

    // Get the details of an asset
    function getAssetDetails(bytes32 _ticker) external view returns (NudexAsset memory);

    // Get the list of all listed assets
    function getAllAssets() external view returns (bytes32[] memory);

    // List a new asset on the specified chain
    function listAsset(bytes32 _ticker, NudexAsset calldata _newAsset) external;

    // Delist an existing asset
    function delistAsset(bytes32 _ticker) external;

    function deposit(bytes32 _ticker, uint256 _assetIndex, uint256 _amount) external;

    function withdraw(bytes32 _ticker, uint256 _assetIndex, uint256 _amount) external;
}
