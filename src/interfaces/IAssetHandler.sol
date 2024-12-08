// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IAssetHandler {
    enum AssetType {
        BTC,
        EVM,
        Ordinal,
        Inscription
    }

    struct Asset {
        string name; // Common name of the asset
        string nuDexName; // Name of the asset within nuDex
        AssetType assetType; // Type of the asset (BTC, EVM, Ordinal, Inscription)
        address contractAddress; // Address for ERC20, Inscription, or 0x0 for BTC/Ordinal/Native token
        uint256 chainId; // Chain ID for EVM-based assets, or specific IDs for BTC/Ordinal
        bool isListed; // Whether the asset is listed
    }

    // events
    event AssetListed(
        bytes32 indexed assetId,
        string name,
        string nuDexName,
        AssetType assetType,
        address contractAddress,
        uint256 chainId
    );
    event AssetDelisted(bytes32 indexed assetId);
    event Deposit(bytes32 indexed assetId, bytes32 indexed addr, uint256 indexed amount);
    event Withdraw(bytes32 indexed assetId, bytes32 indexed addr, uint256 indexed amount);

    // errors
    error InsufficientBalance(bytes32 assetId, bytes32 addr);

    // Create a unique identifier for an asset based on its type, address, and chain ID
    function getAssetIdentifier(
        AssetType assetType,
        address contractAddress,
        uint256 chainId
    ) external pure returns (bytes32);

    // List a new asset on the specified chain
    function listAsset(
        string memory name,
        string memory nuDexName,
        AssetType assetType,
        address contractAddress,
        uint256 chainId
    ) external;

    // Delist an existing asset
    function delistAsset(AssetType assetType, address contractAddress, uint256 chainId) external;

    // Check if an asset is listed
    function isAssetListed(
        AssetType assetType,
        address contractAddress,
        uint256 chainId
    ) external view returns (bool);

    // Get the details of an asset
    function getAssetDetails(bytes32 assetId) external view returns (Asset memory);

    // Get the list of all listed assets
    function getAllAssets() external view returns (bytes32[] memory);
}
