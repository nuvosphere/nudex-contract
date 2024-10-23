// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDepositManager {
    event DepositRecorded(
        address indexed targetAddress,
        uint256 indexed amount,
        uint256 indexed chainId,
        bytes txInfo,
        bytes extraInfo
    );

    struct DepositInfo {
        address targetAddress;
        uint256 amount;
        uint256 chainId;
        bytes txInfo;
        bytes extraInfo;
    }

    function recordDeposit(
        address targetAddress,
        uint256 amount,
        uint256 chainId,
        bytes memory txInfo,
        bytes memory extraInfo
    ) external;

    function getDeposits(address targetAddress) external view returns (DepositInfo[] memory);
}
