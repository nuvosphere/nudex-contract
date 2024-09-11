// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockNuDexOperations {

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

    function isTaskCompleted(uint256 taskId) external view returns (bool) {
        return tasks[taskId].isCompleted;
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

    function submitTask(string memory description, uint _timestamp) external {
        uint256 taskId = nextTaskId++;
        tasks[taskId] = Task({
            id: taskId,
            description: description,
            submitter: msg.sender,
            isCompleted: false,
            createdAt: _timestamp,
            completedAt: 0,
            result: ""
        });
    }

    function markTaskCompleted(uint256 taskId, bytes calldata result) external {
        Task storage task = tasks[taskId];
        task.isCompleted = true;
        task.completedAt = block.timestamp;
        task.result = result;
    }
}
