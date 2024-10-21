// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/INuDexOperations.sol";
import "./interfaces/IParticipantManager.sol";

contract NuDexOperations is INuDexOperations, OwnableUpgradeable {

    uint256 public nextTaskId;
    mapping(uint256 => Task) public tasks;
    IParticipantManager public participantManager;

    modifier onlyParticipant() {
        require(participantManager.isParticipant(msg.sender), "Not a participant");
        _;
    }

    function initialize(address _participantManager, address _initialOwner) public initializer {
        __Ownable_init(_initialOwner);
        participantManager = IParticipantManager(_participantManager);
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

    function isTaskCompleted(uint256 taskId) external view returns (bool) {
        return tasks[taskId].isCompleted;
    }

}
