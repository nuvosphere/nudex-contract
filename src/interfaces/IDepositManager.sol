// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IDepositManager {
    struct DepositInfo {
        address targetAddress;
        uint64 chainId;
        uint256 amount;
        bytes txInfo;
        bytes extraInfo;
    }

    struct WithdrawalInfo {
        address targetAddress;
        uint256 amount;
        uint64 chainId;
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
    error InvalidInput();

    function recordDeposit(
        address targetAddress,
        uint256 amount,
        uint64 chainId,
        bytes memory txInfo,
        bytes memory extraInfo
    ) external returns (bytes memory);

    function recordWithdrawal(
        address targetAddress,
        uint256 amount,
        uint64 chainId,
        bytes memory txInfo,
        bytes memory extraInfo
    ) external returns (bytes memory);

    function getDeposits(address targetAddress) external view returns (DepositInfo[] memory);
    function getWithdrawals(address targetAddress) external view returns (WithdrawalInfo[] memory);
}
