// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IDepositManager.sol";

contract DepositManager is IDepositManager {

    mapping(address => DepositInfo[]) public deposits;

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
