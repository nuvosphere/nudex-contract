// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockNuvoLockUpgradeablePreset {
    function getLockInfo(address) external view returns (uint256 amount, uint256 unlockTime, uint256 originalLockTime, uint256 startTime, uint256 bonusPoints, uint256 accumulatedRewards, uint256 lastClaimedPeriod, uint256 demeritPoints) {
        return (100, block.timestamp + 7 * 24 * 60 * 60, 7 * 24 * 60 * 60, block.timestamp, 0, 0, 0, 0); // Amount below eligibility threshold
    }
}
