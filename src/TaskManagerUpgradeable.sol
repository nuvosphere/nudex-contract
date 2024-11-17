// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ITaskManager} from "./interfaces/ITaskManager.sol";

contract TaskManagerUpgradeable is ITaskManager, OwnableUpgradeable {
    address public taskSubmitter;
    uint256 public nextTaskId;
    uint256 public nextPendingId;
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

    function getTaskState(uint256 _taskId) external view returns (State) {
        return tasks[_taskId].state;
    }

    function getLatestTask() external view returns (Task memory) {
        require(nextTaskId > 0, EmptyTask());
        return tasks[nextTaskId - 1];
    }

    function getUncompletedTasks() external view returns (Task[] memory) {
        Task[] memory tempTasks = new Task[](nextTaskId);
        uint256 count = 0;

        for (uint256 i = 0; i < nextTaskId; i++) {
            if (tasks[i].state != State.Completed) {
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
            state: State.Created,
            createdAt: block.timestamp,
            updatedAt: 0,
            result: ""
        });

        emit TaskSubmitted(taskId, _context, _submitter);
        return taskId;
    }

    function updateTask(uint256 _taskId, State _state, bytes calldata _result) external onlyOwner {
        Task storage task = tasks[_taskId];
        require(_taskId == nextPendingId++ || task.state == State.Pending, "Wrong id");
        task.state = _state;
        task.updatedAt = block.timestamp;
        if (_result.length > 0) {
            task.result = _result;
        }
        emit TaskUpdated(_taskId, task.submitter, block.timestamp, _result);
    }
}
