// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockNuvoLockUpgradeable {
    function getLockInfo(address) external pure returns (uint256 amount, uint256 unlockTime, uint256 originalLockTime, uint256 startTime, uint256 bonusPoints, uint256 accumulatedRewards, uint256 lastClaimedPeriod) {
        return (100, block.timestamp + 7 * 24 * 60 * 60, 7 * 24 * 60 * 60, block.timestamp, 0, 0, 0);
    }
}
