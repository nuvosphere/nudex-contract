// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

enum AssetType {
    BTC,
    EVM,
    Ordinal,
    Inscription
}

interface IAssetHandler {
    struct NudexAsset {
        uint256 id;
        string assetAlias; // Common name of the asset
        string assetLogo;
        AssetType assetType; // Type of the asset (BTC, EVM, Ordinal, Inscription)
        uint8 decimals;
        bool withdrawalEnabled;
        bool depositEnabled;
        bool isListed; // Whether the asset is listed
        uint32 createdTime;
        uint32 updatedTime;
        uint256 withdrawFee;
        uint256 minWithdrawAmount;
        uint256 minDepositAmount;
        bytes32[] withdrawalChains;
        bytes32[] depositChains;
    }

    struct OnchainAsset {
        uint256 id;
        AssetType assetType; // Type of the asset (BTC, EVM, Ordinal, Inscription)
        address contractAddress; // Address for ERC20, Inscription, or 0x0 for BTC/Ordinal/Native token
        string symbol;
        bytes32 tokenAddr;
        uint8 decimals;
        uint256 balance;
    }

    // events
    event AssetListed(bytes32 indexed ticker, NudexAsset newAsset);
    event AssetDelisted(bytes32 indexed assetId);
    event Deposit(bytes32 indexed assetId, bytes32 indexed addr, uint256 indexed amount);
    event Withdraw(bytes32 indexed assetId, bytes32 indexed addr, uint256 indexed amount);

    // errors
    error InsufficientBalance(bytes32 assetId, bytes32 addr);

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

    function deposit(
        bytes32 _ticker,
        AssetType _assetType,
        address _contractAddress,
        uint256 _chainId,
        bytes32 _address,
        uint256 _amount
    ) external;

    function withdraw(
        bytes32 _ticker,
        AssetType _assetType,
        address _contractAddress,
        uint256 _chainId,
        bytes32 _address,
        uint256 _amount
    ) external;
}
