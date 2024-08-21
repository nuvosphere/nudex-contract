// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface INuvoToken {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract NuvoLockUpgradeable is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    INuvoToken public nuvoToken;
    address public rewardSource;
    uint256 public minLockPeriod;

    struct RewardInfo {
        uint256 ratio;
        uint256 startTime;
    }
    RewardInfo[] public rewardHistory;

    struct LockInfo {
        uint256 amount;
        uint256 unlockTime;
        uint256 originalLockTime;
        uint256 startTime;
    }

    mapping(address => LockInfo) public locks;

    event Locked(address indexed user, uint256 amount, uint256 unlockTime);
    event Unlocked(address indexed user, uint256 amount);
    event MinLockPeriodUpdated(uint256 newMinLockPeriod);
    event RewardRatioUpdated(uint256 newRewardRatio, uint256 timeUpdated);
    event LockPeriodIncreased(address indexed user, uint256 newUnlockTime);
    event PartialUnlocked(address indexed user, uint256 amount);
    event RewardSourceUpdated(address indexed newRewardSource);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(address _nuvoToken, address _rewardSource) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();

        nuvoToken = INuvoToken(_nuvoToken);
        rewardSource = _rewardSource;
        minLockPeriod = 90 days;

        // Initialize with a default reward ratio
        rewardHistory.push(RewardInfo({ratio: 100, startTime: block.timestamp}));
    }

    function lock(uint256 amount, uint256 period) external {
        require(period >= minLockPeriod, "Lock period is too short");
        require(amount > 0, "Amount must be greater than 0");

        LockInfo storage lockInfo = locks[msg.sender];
        require(lockInfo.amount == 0, "Already locked");

        uint256 unlockTime = block.timestamp + period;

        require(nuvoToken.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        lockInfo.amount = amount;
        lockInfo.unlockTime = unlockTime;
        lockInfo.originalLockTime = period;
        lockInfo.startTime = block.timestamp;

        emit Locked(msg.sender, amount, unlockTime);
    }

    function unlock() external {
        LockInfo storage lockInfo = locks[msg.sender];
        require(lockInfo.amount > 0, "No locked tokens");
        require(block.timestamp >= lockInfo.unlockTime, "Tokens are still locked");

        uint256 amount = lockInfo.amount;
        lockInfo.amount = 0;

        require(nuvoToken.transfer(msg.sender, amount), "Token transfer failed");

        uint256 reward = calculateReward(lockInfo.startTime, lockInfo.unlockTime, amount);
        require(nuvoToken.transferFrom(rewardSource, msg.sender, reward), "Reward transfer failed");

        emit Unlocked(msg.sender, amount);
    }

    function partialUnlock(uint256 amount) external {
        LockInfo storage lockInfo = locks[msg.sender];
        require(lockInfo.amount >= amount, "Insufficient locked tokens");
        require(block.timestamp >= lockInfo.unlockTime, "Tokens are still locked");

        uint256 remainingAmount = lockInfo.amount - amount;
        lockInfo.amount = remainingAmount;

        require(nuvoToken.transfer(msg.sender, amount), "Token transfer failed");

        uint256 reward = calculateReward(lockInfo.startTime, lockInfo.unlockTime, amount);
        require(nuvoToken.transferFrom(rewardSource, msg.sender, reward), "Reward transfer failed");

        emit PartialUnlocked(msg.sender, amount);
    }

    function increaseLockPeriod(uint256 additionalPeriod) external {
        require(additionalPeriod > 0, "Additional period must be greater than 0");

        LockInfo storage lockInfo = locks[msg.sender];
        require(lockInfo.amount > 0, "No locked tokens");

        lockInfo.unlockTime += additionalPeriod;

        emit LockPeriodIncreased(msg.sender, lockInfo.unlockTime);
    }

    function extendLock(uint256 additionalPeriod) external {
        require(additionalPeriod > 0, "Additional period must be greater than 0");

        LockInfo storage lockInfo = locks[msg.sender];
        require(lockInfo.amount > 0, "No locked tokens");
        require(lockInfo.unlockTime > block.timestamp, "Lock period has already expired");

        lockInfo.unlockTime += additionalPeriod;

        emit LockPeriodIncreased(msg.sender, lockInfo.unlockTime);
    }

    function getLockInfo(address user) external view returns (uint256 amount, uint256 unlockTime, uint256 originalLockTime, uint256 startTime) {
        LockInfo storage lockInfo = locks[user];
        return (lockInfo.amount, lockInfo.unlockTime, lockInfo.originalLockTime, lockInfo.startTime);
    }

    function updateMinLockPeriod(uint256 newMinLockPeriod) external onlyOwner {
        minLockPeriod = newMinLockPeriod;
        emit MinLockPeriodUpdated(newMinLockPeriod);
    }

    function updateRewardRatio(uint256 newRewardRatio) external onlyOwner {
        rewardHistory.push(RewardInfo({ratio: newRewardRatio, startTime: block.timestamp}));
        emit RewardRatioUpdated(newRewardRatio, block.timestamp);
    }

    function updateRewardSource(address newRewardSource) external onlyOwner {
        require(newRewardSource != address(0), "Invalid reward source address");
        rewardSource = newRewardSource;
        emit RewardSourceUpdated(newRewardSource);
    }

    function calculateReward(uint256 lockStartTime, uint256 unlockTime, uint256 amount) internal view returns (uint256) {
        uint256 reward = 0;
        uint256 lastTime = lockStartTime;

        for (uint256 i = 0; i < rewardHistory.length; i++) {
            RewardInfo memory info = rewardHistory[i];
            uint256 nextTime = (i + 1 < rewardHistory.length) ? rewardHistory[i + 1].startTime : unlockTime;

            if (lockStartTime < info.startTime) {
                continue;
            }

            if (unlockTime <= info.startTime) {
                break;
            }

            uint256 duration = (nextTime <= unlockTime ? nextTime : unlockTime) - lastTime;
            reward += info.ratio * amount * duration / 1e18;
            lastTime = nextTime;

            if (nextTime >= unlockTime) {
                break;
            }
        }

        return reward;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
