// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INuvoToken {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface INuvoLock {
    event Locked(address indexed user, uint256 amount, uint256 unlockTime);
    event Unlocked(address indexed user, uint256 amount);
    event MinLockInfo(uint256 indexed amount, uint256 indexed period);
    event RewardsAccumulated(address indexed user, uint256 rewards);
    event RewardsClaimed(address indexed user, uint256 rewards);
    event RewardPerPeriodUpdated(uint256 newRewardPerPeriod, uint256 period);
    event DemeritPointsIncreased(address indexed submitter, uint256 points);

    error AlreadyLocked();
    error InvalidAmount();
    error UnlockedTimeNotReached();
    error NotAUser(address user, uint256 amount);
    error NothingToClaim();
    error TimePeriodBelowMin();
    error TransaferFailed();

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

    function totalLocked() external view returns (uint256);

    function lock(uint256 amount, uint256 period) external;

    function unlock() external;

    function accumulateBonusPoints(address participant) external;

    function accumulateDemeritPoints(address participant) external;

    function setMinLockInfo(uint256 _minLockAmount, uint256 _minLockPeriod) external;

    function setRewardPerPeriod(uint256 newRewardPerPeriod) external;

    function claimRewards() external;

    function getCurrentPeriod() external view returns (uint256);

    function getLockInfo(
        address participant
    )
        external
        view
        returns (
            uint256 amount,
            uint256 unlockTime,
            uint256 originalLockTime,
            uint256 startTime,
            uint256 bonusPoints,
            uint256 accumulatedRewards,
            uint256 lastClaimedPeriod,
            uint256 demeritPoints
        );

    function lockedBalanceOf(address participant) external view returns (uint256);

    function lockedTime(address participant) external view returns (uint256);
}
