// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

enum AssetType {
    BTC,
    TRON,
    SOL,
    EVM,
    Ordinal,
    Inscription
}

struct AssetParam {
    AssetType assetType; // Type of the asset (BTC, EVM, Ordinal, Inscription)
    uint8 decimals;
    bool depositEnabled;
    bool withdrawalEnabled;
    uint256 minDepositAmount;
    uint256 minWithdrawAmount;
    string assetAlias; // Common name of the asset
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
    uint256 minDepositAmount;
    uint256 minWithdrawAmount;
    string assetAlias; // Common name of the asset
}

struct TokenInfo {
    bytes32 chainId; // Chain ID for EVM-based assets, or specific IDs for BTC/Ordinal
    bool isActive;
    AssetType assetType; // Type of the asset (BTC, EVM, Ordinal, Inscription)
    uint8 decimals;
    string contractAddress; // Address for ERC20, Inscription, or 0x0 for BTC/Ordinal/Native token
    string symbol;
    uint256 withdrawFee;
    uint256 balance; // The balance of deposited token
    uint256 btcCount; // BTC count
}

interface IAssetHandler {
    // events
    event AssetListed(bytes32 indexed ticker, AssetParam assetParam);
    event AssetUpdated(bytes32 indexed ticker, AssetParam assetParam);
    event AssetDelisted(bytes32 indexed assetId);
    event LinkToken(bytes32 indexed ticker, TokenInfo[] tokens);
    event ResetlinkedToken(bytes32 indexed ticker);
    event TokenSwitch(bytes32 ticker, bytes32 chainId, bool isActive);
    event Consolidate(
        bytes32 indexed assetId,
        bytes32 indexed chainId,
        uint256 indexed amount,
        uint256 btcAmount
    );
    event Withdraw(
        bytes32 indexed assetId,
        bytes32 indexed chainId,
        uint256 indexed amount,
        uint256 btcAmount
    );

    // errors
    error InsufficientBalance(bytes32 ticker, bytes32 chainId);
    error InsufficientBtcCount(bytes32 ticker, bytes32 chainId);
    error AssetNotListed(bytes32 ticker);

    // Check if an asset is listed
    function isAssetListed(bytes32 _ticker) external view returns (bool);

    // Get the details of an asset
    function getAssetDetails(bytes32 _ticker) external view returns (NudexAsset memory);

    // Get the list of all listed assets
    function getAllAssets() external view returns (bytes32[] memory);

    function withdraw(
        bytes32 _ticker,
        bytes32 _chainId,
        uint256 _amount,
        uint256 _btcAmount
    ) external;
}
