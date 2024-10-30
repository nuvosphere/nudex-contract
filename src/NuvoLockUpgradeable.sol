// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {INuvoLock, INuvoToken} from "./interfaces/INuvoLock.sol";

contract NuvoLockUpgradeable is INuvoLock, OwnableUpgradeable {
    INuvoToken public nuvoToken;
    address public rewardSource;
    uint256 public minLockAmount;
    uint256 public minLockPeriod;
    uint256 public currentPeriodStart;
    uint256 public totalBonusPoints;
    uint256 public totalLocked;
    uint256 public lastPeriodNumber; // Tracks the last reward period

    mapping(address => LockInfo) public locks;
    mapping(uint256 => uint256) public rewardPerPeriod; // Maps period number to its reward amount
    address[] public users;
    mapping(address => uint256) public userIndex;

    modifier onlyParticipant() {
        require(locks[msg.sender].amount > 0, NotAUser());
        _;
    }

    function initialize(
        address _nuvoToken,
        address _rewardSource,
        address _owner,
        uint256 _minLockAmount,
        uint256 _minLockPeriod
    ) public initializer {
        __Ownable_init(_owner);

        nuvoToken = INuvoToken(_nuvoToken);
        rewardSource = _rewardSource;
        currentPeriodStart = block.timestamp;
        minLockPeriod = _minLockPeriod;
        minLockAmount = _minLockAmount;
        lastPeriodNumber = getCurrentPeriod();
    }

    function getCurrentPeriod() public view returns (uint256) {
        return (block.timestamp - currentPeriodStart) / 1 weeks;
    }

    function getLockInfo(
        address userAddr
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
            uint256 demeritPoints // TODO: this was not added, is it intended?
        )
    {
        LockInfo memory lockInfo = locks[userAddr];
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

    function lockedBalanceOf(address userAddr) external view returns (uint256) {
        return locks[userAddr].amount;
    }

    function lockedTime(address userAddr) external view returns (uint256) {
        return block.timestamp - locks[userAddr].startTime;
    }

    function setMinLockAmount(uint256 _minLockAmount) public onlyOwner {
        minLockAmount = _minLockAmount;
    }

    function setMinLockPeriod(uint256 _minLockPeriod) public onlyOwner {
        minLockPeriod = _minLockPeriod;
    }

    function lock(uint256 _amount, uint256 _period) external {
        require(_amount >= minLockAmount, InvalidAmount());
        require(_period >= minLockPeriod, TimePeriodBelowMin());
        require(locks[msg.sender].amount == 0, AlreadyLocked());

        uint256 unlockTime = block.timestamp + _period;
        locks[msg.sender] = LockInfo({
            amount: _amount,
            unlockTime: unlockTime,
            originalLockTime: _period,
            startTime: block.timestamp,
            bonusPoints: 0,
            accumulatedRewards: 0,
            lastClaimedPeriod: lastPeriodNumber,
            demeritPoints: 0
        });

        // Transfer NUVO tokens from the user to the contract
        require(nuvoToken.transferFrom(msg.sender, address(this), _amount), TransaferFailed());
        totalLocked += _amount;
        // record userAddr
        userIndex[msg.sender] = users.length;
        users.push(msg.sender);

        emit Locked(msg.sender, _amount, unlockTime);
    }

    function unlock() external onlyParticipant {
        LockInfo storage lockInfo = locks[msg.sender];
        require(block.timestamp >= lockInfo.unlockTime, UnlockedTimeNotReached());
        // Accumulate rewards for all unaccounted periods before unlocking
        accumulateRewards();

        uint256 amount = lockInfo.amount;
        lockInfo.amount = 0;
        totalLocked -= amount;
        // remove userAddr
        users[userIndex[msg.sender]] = users[users.length - 1];
        users.pop();
        require(nuvoToken.transfer(msg.sender, amount), TransaferFailed());

        emit Unlocked(msg.sender, amount);
    }

    function accumulateBonusPoints(address _userAddr) external onlyOwner {
        require(locks[_userAddr].amount > 0, NotAUser());

        // Check if the reward period has ended and accumulate rewards if necessary
        if (getCurrentPeriod() > lastPeriodNumber) {
            accumulateRewards();
        }

        // Accumulate points
        locks[_userAddr].bonusPoints++;
        totalBonusPoints++;
    }

    function accumulateDemeritPoints(address _userAddr) external onlyOwner {
        require(locks[_userAddr].amount > 0, NotAUser());

        // Check if the reward period has ended and accumulate rewards if necessary
        if (getCurrentPeriod() > lastPeriodNumber) {
            accumulateRewards();
        }

        // Accumulate points
        locks[_userAddr].demeritPoints++;
    }

    function setRewardPerPeriod(uint256 newRewardPerPeriod) external onlyOwner {
        // Accumulate rewards for all previous periods before updating the reward per period
        accumulateRewards();

        // Update rewardPerPeriod for the current period
        rewardPerPeriod[lastPeriodNumber] = newRewardPerPeriod;

        emit RewardPerPeriodUpdated(newRewardPerPeriod, lastPeriodNumber);
    }

    // calculate reward of every user for the last period
    function accumulateRewards() public {
        uint256 currentPeriodNumber = getCurrentPeriod();

        if (currentPeriodNumber > lastPeriodNumber) {
            if (totalBonusPoints > 0 && rewardPerPeriod[lastPeriodNumber] > 0) {
                address userAddr;
                LockInfo storage lockInfo;
                for (uint256 i = 0; i < users.length; i++) {
                    userAddr = users[i];
                    lockInfo = locks[userAddr];
                    uint256 userBonusPoints = (lockInfo.bonusPoints > lockInfo.demeritPoints)
                        ? lockInfo.bonusPoints - lockInfo.demeritPoints
                        : 0;
                    if (lockInfo.demeritPoints > 0) {
                        lockInfo.demeritPoints--;
                    }

                    if (userBonusPoints > 0) {
                        uint256 userReward = (rewardPerPeriod[lastPeriodNumber] * userBonusPoints) /
                            totalBonusPoints;
                        lockInfo.accumulatedRewards += userReward;

                        emit RewardsAccumulated(userAddr, userReward);
                    }

                    // Reset bonus points for the user during the same loop
                    lockInfo.bonusPoints = 0;
                }

                // Reset the total bonus points for the next period
                totalBonusPoints = 0;
                // Update the current period and its start time
                lastPeriodNumber = currentPeriodNumber;
                currentPeriodStart += (currentPeriodNumber - lastPeriodNumber) * 1 weeks;
            }
        }
    }

    function claimRewards() external onlyParticipant {
        LockInfo storage lockInfo = locks[msg.sender];
        uint256 rewards = lockInfo.accumulatedRewards;
        require(rewards > 0, NothingToClaim());

        lockInfo.accumulatedRewards = 0;
        require(nuvoToken.transferFrom(rewardSource, msg.sender, rewards), TransaferFailed());

        emit RewardsClaimed(msg.sender, rewards);
    }
}
