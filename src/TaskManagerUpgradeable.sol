// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ITaskManager, State} from "./interfaces/ITaskManager.sol";

contract TaskManagerUpgradeable is ITaskManager, OwnableUpgradeable {
    address public taskSubmitter;
    uint64 public nextTaskId;
    uint64 public nextCreatedTaskId;
    uint64 public pendingTaskIndex;
    uint64[] public pendingTasks;
    uint64[] public preconfirmedTasks;
    bytes[] public preconfirmedTaskResults;
    mapping(uint64 => Task) public tasks;
    mapping(bytes32 => uint64) public taskRecords;

    // _owner: votingManager
    function initialize(address _taskSubmitter, address _owner) public initializer {
        __Ownable_init(_owner);
        taskSubmitter = _taskSubmitter;
    }

    function setTaskSubmitter(address _taskSubmitter) external onlyOwner {
        require(_taskSubmitter != address(0), InvalidAddress());
        taskSubmitter = _taskSubmitter;
    }

    function getTaskState(uint64 _taskId) external view returns (State) {
        return tasks[_taskId].state;
    }

    function getLatestTask() external view returns (Task memory) {
        require(nextTaskId > 0, EmptyTask());
        return tasks[nextTaskId - 1];
    }

    function getUncompletedTasks() external view returns (Task[] memory) {
        Task[] memory tempTasks = new Task[](nextTaskId);
        uint256 count = 0;

        for (uint64 i = 0; i < nextTaskId; i++) {
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

    function submitTask(address _submitter, bytes calldata _context) external returns (uint64) {
        require(msg.sender == taskSubmitter, OnlyTaskSubmitter());

        bytes32 hash = keccak256(_context);
        uint64 taskId = taskRecords[hash];
        require(taskId == 0, AlreadyExistTask(taskId));
        taskId = nextTaskId++;
        tasks[taskId] = Task({
            id: taskId,
            state: State.Created,
            submitter: _submitter,
            createdAt: block.timestamp,
            updatedAt: 0,
            context: _context,
            result: ""
        });
        taskRecords[hash] = taskId;

        emit TaskSubmitted(taskId, _context, _submitter);
        return taskId;
    }

    function updateTask(uint64 _taskId, State _state, bytes calldata _result) external onlyOwner {
        Task storage task = tasks[_taskId];
        if (task.state == State.Created) {
            require(_taskId == nextCreatedTaskId++, InvalidTask(_taskId));
        }
        if (task.state == State.Pending) {
            require(_taskId == pendingTasks[pendingTaskIndex++], InvalidPendingTask(_taskId));
        }
        if (_state == State.Pending) {
            pendingTasks.push(_taskId);
        }
        task.state = _state;
        task.updatedAt = block.timestamp;
        if (_result.length > 0) {
            task.result = _result;
        }
        emit TaskUpdated(_taskId, task.submitter, block.timestamp, _state, _result);
    }
}
