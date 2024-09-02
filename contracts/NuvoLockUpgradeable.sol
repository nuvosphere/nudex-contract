// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/INuvoLock.sol";

contract NuvoLockUpgradeable is INuvoLock, Initializable, UUPSUpgradeable, OwnableUpgradeable {
    INuvoToken public nuvoToken;
    address public rewardSource;
    uint256 public minLockPeriod;
    uint256 public currentPeriodStart;
    uint256 public totalBonusPoints;
    uint256 public totalLocked;
    uint256 public currentPeriod; // Tracks the current reward period

    mapping(address => LockInfo) public locks;
    mapping(uint256 => uint256) public rewardPerPeriod; // Maps period number to its reward amount
    address[] public participants;

    modifier onlyParticipant() {
        require(locks[msg.sender].amount > 0, "Not a participant");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(address _nuvoToken, address _rewardSource, address _initialOwner) initializer public {
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();

        nuvoToken = INuvoToken(_nuvoToken);
        rewardSource = _rewardSource;
        currentPeriodStart = block.timestamp;
        currentPeriod = 0;
    }

    function lock(uint256 amount, uint256 period) external {
        require(period >= minLockPeriod, "Lock period is too short");
        require(amount > 0, "Amount must be greater than 0");

        LockInfo storage lockInfo = locks[msg.sender];
        require(lockInfo.amount == 0, "Already locked");

        uint256 unlockTime = block.timestamp + period;

        // Transfer NUVO tokens from the user to the contract
        require(nuvoToken.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        // Store lock information
        lockInfo.amount = amount;
        lockInfo.unlockTime = unlockTime;
        lockInfo.originalLockTime = period;
        lockInfo.startTime = block.timestamp;
        lockInfo.bonusPoints = 0;
        lockInfo.accumulatedRewards = 0;
        lockInfo.lastClaimedPeriod = currentPeriod;

        totalLocked += amount;

        participants.push(msg.sender);

        emit Locked(msg.sender, amount, unlockTime);
    }

    function unlock() external onlyParticipant {
        LockInfo storage lockInfo = locks[msg.sender];
        require(block.timestamp >= lockInfo.unlockTime, "Tokens are still locked");

        uint256 amount = lockInfo.amount;
        lockInfo.amount = 0;
        totalLocked -= amount;

        // Accumulate rewards for all unaccounted periods before unlocking
        accumulateRewards();

        require(nuvoToken.transfer(msg.sender, amount), "Token transfer failed");

        emit Unlocked(msg.sender, amount);
    }

    function accumulateBonusPoints(address participant) external onlyOwner {
        require(locks[participant].amount > 0, "Not a participant");

        // Check if the reward period has ended and accumulate rewards if necessary
        uint256 currentPeriodNumber = getCurrentPeriod();
        if (currentPeriodNumber > currentPeriod) {
            accumulateRewards();
        }

        // Accumulate points
        locks[participant].bonusPoints++;
        totalBonusPoints++;
    }

    function accumulateDemeritPoints(address participant) external onlyOwner {
        require(locks[participant].amount > 0, "Not a participant");

        // Check if the reward period has ended and accumulate rewards if necessary
        uint256 currentPeriodNumber = getCurrentPeriod();
        if (currentPeriodNumber > currentPeriod) {
            accumulateRewards();
        }

        // Accumulate points
        locks[participant].demeritPoints++;
    }

    function setRewardPerPeriod(uint256 newRewardPerPeriod) external onlyOwner {
        // Accumulate rewards for all previous periods before updating the reward per period
        accumulateRewards();

        // Update rewardPerPeriod for the current period
        rewardPerPeriod[currentPeriod] = newRewardPerPeriod;

        emit RewardPerPeriodUpdated(newRewardPerPeriod, currentPeriod);
    }

    function accumulateRewards() internal {
        uint256 currentPeriodNumber = getCurrentPeriod();

        if (currentPeriodNumber > currentPeriod) {
            if (totalBonusPoints > 0 && rewardPerPeriod[currentPeriod] > 0) {
                for (uint256 i = 0; i < participants.length; i++) {
                    address participant = participants[i];
                    LockInfo storage lockInfo = locks[participant];
                    uint256 participantBonusPoints = (lockInfo.bonusPoints > lockInfo.demeritPoints)?lockInfo.bonusPoints - lockInfo.demeritPoints:0;
                    if (lockInfo.demeritPoints > 0) {
                        lockInfo.demeritPoints--;
                    }

                    if (participantBonusPoints > 0) {
                        uint256 participantReward = (rewardPerPeriod[currentPeriod] * participantBonusPoints) / totalBonusPoints;
                        lockInfo.accumulatedRewards += participantReward;

                        emit RewardsAccumulated(participant, participantReward);
                    }

                    // Reset bonus points for the participant during the same loop
                    lockInfo.bonusPoints = 0;
                }
            }

            // Reset the total bonus points for the next period
            totalBonusPoints = 0;

            // Update the current period and its start time
            currentPeriod = currentPeriodNumber;
            currentPeriodStart += (currentPeriodNumber - currentPeriod) * 1 weeks;
        }
    }


    function claimRewards() external onlyParticipant {
        LockInfo storage lockInfo = locks[msg.sender];
        uint256 rewards = lockInfo.accumulatedRewards;
        require(rewards > 0, "No rewards to claim");

        lockInfo.accumulatedRewards = 0;

        require(nuvoToken.transferFrom(rewardSource, msg.sender, rewards), "Reward transfer failed");

        emit RewardsClaimed(msg.sender, rewards);
    }

    function getCurrentPeriod() public view returns (uint256) {
        return (block.timestamp - currentPeriodStart) / 1 weeks;
    }

    function getLockInfo(
        address participant
    ) 
        public 
        view 
        returns (
            uint256 amount, 
            uint256 unlockTime, 
            uint256 originalLockTime, 
            uint256 startTime,
            uint256 bonusPoints,
            uint256 accumulatedRewards,
            uint256 lastClaimedPeriod
        ) 
    {
        LockInfo storage lockInfo = locks[participant];
        return (
            lockInfo.amount,
            lockInfo.unlockTime,
            lockInfo.originalLockTime,
            lockInfo.startTime,
            lockInfo.bonusPoints,
            lockInfo.accumulatedRewards,
            lockInfo.lastClaimedPeriod
        );
    }

    function lockedBalanceOf(address participant) external view returns(uint256) {
        return locks[participant].amount;
    }

    function lockedTime(address participant) external view returns(uint256) {
        return block.timestamp - locks[participant].startTime;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
