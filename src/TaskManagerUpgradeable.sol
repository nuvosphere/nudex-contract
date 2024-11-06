// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ITaskManager} from "./interfaces/ITaskManager.sol";

contract TaskManagerUpgradeable is ITaskManager, OwnableUpgradeable {
    address public taskSubmitter;
    uint256 public nextTaskId;
    uint256[] public preconfirmedTasks;
    bytes[] public preconfirmedTaskResults;
    mapping(uint256 => Task) public tasks;

    // _owner: votingManager
    function initialize(address _taskSubmitter, address _owner) public initializer {
        __Ownable_init(_owner);
        taskSubmitter = _taskSubmitter;
    }

    function setTaskSubmitter(address _taskSubmitter) external onlyOwner {
        require(_taskSubmitter != address(0));
        taskSubmitter = _taskSubmitter;
    }

    function isTaskCompleted(uint256 _taskId) external view returns (bool) {
        return tasks[_taskId].isCompleted;
    }

    function getLatestTask() external view returns (Task memory) {
        require(nextTaskId > 0, EmptyTask());
        return tasks[nextTaskId - 1];
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

    function submitTask(address _submitter, bytes calldata _context) external returns (uint256) {
        require(msg.sender == taskSubmitter, OnlyTaskSubmitter());
        uint256 taskId = nextTaskId++;
        tasks[taskId] = Task({
            id: taskId,
            context: _context,
            submitter: _submitter,
            isCompleted: false,
            createdAt: block.timestamp,
            completedAt: 0,
            result: ""
        });

        emit TaskSubmitted(taskId, _context, _submitter);
        return taskId;
    }

    function markTaskCompleted(uint256 _taskId, bytes calldata _result) external onlyOwner {
        Task storage task = tasks[_taskId];
        task.isCompleted = true;
        task.completedAt = block.timestamp;
        task.result = _result;
        emit TaskCompleted(_taskId, task.submitter, block.timestamp, _result);
    }

    function markTaskCompleted_Batch(
        uint256[] calldata _taskIds,
        bytes[] calldata _results
    ) external onlyOwner {
        Task storage task;
        for (uint256 i; i < _taskIds.length; ++i) {
            task = tasks[_taskIds[i]];
            task.isCompleted = true;
            task.completedAt = block.timestamp;
            task.result = _results[i];
            emit TaskCompleted(_taskIds[i], task.submitter, block.timestamp, _results[i]);
        }
    }

    function preconfirmTask(uint256 _taskId, bytes calldata _result) external onlyOwner {
        preconfirmedTasks.push(_taskId);
        preconfirmedTaskResults.push(_result);
    }

    function confirmAllTasks() external onlyOwner {
        Task storage task;
        for (uint256 i; i < preconfirmedTasks.length; ++i) {
            task = tasks[preconfirmedTasks[i]];
            task.isCompleted = true;
            task.completedAt = block.timestamp;
            task.result = preconfirmedTaskResults[i];
            emit TaskCompleted(
                preconfirmedTasks[i],
                task.submitter,
                block.timestamp,
                preconfirmedTaskResults[i]
            );
        }
        delete preconfirmedTasks;
        delete preconfirmedTaskResults;
    }
}
