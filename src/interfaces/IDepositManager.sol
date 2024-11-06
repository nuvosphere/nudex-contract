// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IDepositManager {
    struct DepositInfo {
        address targetAddress;
        uint48 chainId;
        uint256 amount;
        bytes txInfo;
        bytes extraInfo;
    }

    struct WithdrawalInfo {
        address targetAddress;
        uint256 amount;
        uint48 chainId;
        bytes txInfo;
        bytes extraInfo;
    }

    event DepositRecorded(
        address indexed targetAddress,
        uint256 indexed amount,
        uint256 indexed chainId,
        bytes txInfo,
        bytes extraInfo
    );
    event WithdrawalRecorded(
        address indexed targetAddress,
        uint256 indexed amount,
        uint256 indexed chainId,
        bytes txInfo,
        bytes extraInfo
    );

    error InvalidAmount();

    function recordDeposit(
        address targetAddress,
        uint256 amount,
        uint48 chainId,
        bytes memory txInfo,
        bytes memory extraInfo
    ) external returns (bytes memory);

    function record_Batch(
        address[] calldata targetAddresses,
        uint256[] calldata amounts,
        uint48[] calldata chainIds,
        bytes[] calldata txInfos,
        bytes[] calldata extraInfos
    ) external returns (bytes[] memory);

    function recordWithdrawal(
        address targetAddress,
        uint256 amount,
        uint48 chainId,
        bytes memory txInfo,
        bytes memory extraInfo
    ) external returns (bytes memory);

    function getDeposits(address targetAddress) external view returns (DepositInfo[] memory);
    function getWithdrawals(address targetAddress) external view returns (WithdrawalInfo[] memory);
}
