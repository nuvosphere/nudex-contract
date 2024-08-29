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
        bytes result;
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
        __Ownable_init(msg.sender);
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
            completedAt: 0,
            result: ""
        });

        emit TaskSubmitted(taskId, description, msg.sender);
    }

    function getLatestTask() external view onlyParticipant returns (Task memory) {
        require(nextTaskId > 0, "No tasks available");
        return tasks[nextTaskId - 1];
    }

    function markTaskCompleted(uint256 taskId, bytes calldata result) external onlyOwner {
        Task storage task = tasks[taskId];
        task.isCompleted = true;
        task.completedAt = block.timestamp;
        task.result = result;
        emit TaskCompleted(taskId, task.submitter, task.completedAt);
    }

    function getUncompletedTasks() external view returns (Task[] memory) {
        Task[] memory tempTasks = new Task[](nextTaskId);
        uint256 count = 0;

        for (uint256 i = 0; i < nextTaskId; i++) {
            if (!tasks[i].isCompleted) {
                tempTasks[count] = tasks[i];
                count++;
            }
        }

        // Allocate exact size array and copy
        Task[] memory uncompletedTasks = new Task[](count);
        for (uint256 i = 0; i < count; i++) {
            uncompletedTasks[i] = tempTasks[i];
        }

        return uncompletedTasks;
    }

}
