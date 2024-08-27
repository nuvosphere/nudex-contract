// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockNuvoLockUpgradeable {
    struct LockInfo {
        uint256 amount;
        uint256 unlockTime;
        uint256 originalLockTime;
        uint256 startTime;
        uint256 bonusPoints;
        uint256 accumulatedRewards;
        uint256 lastClaimedPeriod;
        uint256 demeritPoints;
    }

    mapping(address => LockInfo) public locks;

    function accumulateBonusPoints(address participant) external {
        locks[participant].bonusPoints += 1;
    }

    function accumulateDemeritPoints(address participant) external {
        locks[participant].demeritPoints += 1;
    }

    function getLockInfo(address participant) external view returns (
        uint256 amount, 
        uint256 unlockTime, 
        uint256 originalLockTime, 
        uint256 startTime, 
        uint256 bonusPoints, 
        uint256 accumulatedRewards, 
        uint256 lastClaimedPeriod, 
        uint256 demeritPoints
    ) {
        LockInfo storage lockInfo = locks[participant];
        return (
            lockInfo.amount,
            lockInfo.unlockTime,
            lockInfo.originalLockTime,
            lockInfo.startTime,
            lockInfo.bonusPoints,
            lockInfo.accumulatedRewards,
            lockInfo.lastClaimedPeriod,
            lockInfo.demeritPoints
        );
    }

    // Optionally, you can have a function to initialize default lock info if needed
    function initializeLockInfo(address participant, uint256 amount, uint256 initialDemeritPoints) external {
        locks[participant] = LockInfo({
            amount: amount,
            unlockTime: block.timestamp + 7 days,
            originalLockTime: 7 days,
            startTime: block.timestamp,
            bonusPoints: 0,
            accumulatedRewards: 0,
            lastClaimedPeriod: 0,
            demeritPoints: initialDemeritPoints
        });
    }
}
