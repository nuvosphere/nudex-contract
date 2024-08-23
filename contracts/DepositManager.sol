// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DepositManager {
    struct DepositInfo {
        address targetAddress;
        uint256 amount;
        bytes txInfo;
        uint256 chainId;
        bytes extraInfo;
    }

    mapping(address => DepositInfo[]) public deposits;

    event DepositRecorded(
        address indexed targetAddress,
        uint256 amount,
        bytes txInfo,
        uint256 chainId,
        bytes extraInfo
    );

    function recordDeposit(
        address targetAddress,
        uint256 amount,
        bytes memory txInfo,
        uint256 chainId,
        bytes memory extraInfo
    ) external {
        DepositInfo memory newDeposit = DepositInfo({
            targetAddress: targetAddress,
            amount: amount,
            txInfo: txInfo,
            chainId: chainId,
            extraInfo: extraInfo
        });

        deposits[targetAddress].push(newDeposit);

        emit DepositRecorded(targetAddress, amount, txInfo, chainId, extraInfo);
    }

    function getDeposits(address targetAddress) external view returns (DepositInfo[] memory) {
        return deposits[targetAddress];
    }
}
