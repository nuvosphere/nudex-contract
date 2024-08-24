// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./ParticipantManager.sol";

contract NuDexOperations is OwnableUpgradeable {
    struct Task {
        uint256 id;
        string description;
        address submitter;
        bool isCompleted;
        uint256 createdAt;
        uint256 completedAt;
    }

    uint256 public nextTaskId;
    mapping(uint256 => Task) public tasks;
    ParticipantManager public participantManager;

    event TaskSubmitted(uint256 indexed taskId, string description, address indexed submitter);
    event TaskCompleted(uint256 indexed taskId, address indexed submitter, uint256 completedAt);

    modifier onlyParticipant() {
        require(participantManager.isParticipant(msg.sender), "Not a participant");
        _;
    }

    function initialize(address _participantManager) public initializer {
        __Ownable_init();
        participantManager = ParticipantManager(_participantManager);
    }

    function submitTask(string memory description) external onlyParticipant {
        uint256 taskId = nextTaskId++;
        tasks[taskId] = Task({
            id: taskId,
            description: description,
            submitter: msg.sender,
            isCompleted: false,
            createdAt: block.timestamp,
            completedAt: 0
        });

        emit TaskSubmitted(taskId, description, msg.sender);
    }

    function getLatestTask() external view onlyParticipant returns (Task memory) {
        require(nextTaskId > 0, "No tasks available");
        return tasks[nextTaskId - 1];
    }

    function markTaskCompleted(uint256 taskId) external onlyOwner {
        Task storage task = tasks[taskId];
        task.isCompleted = true;
        task.completedAt = block.timestamp;
        emit TaskCompleted(taskId, task.submitter, task.completedAt);
    }
}
