// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ITaskManager, State} from "./interfaces/ITaskManager.sol";

contract TaskManagerUpgradeable is ITaskManager, OwnableUpgradeable {
    address public taskSubmitter;
    uint64 public nextTaskId;
    uint64 public nextCreatedTaskId;
    uint64 public pendingTaskIndex;
    Task[] public uncompletedTasks;
    uint64[] public pendingTasks;
    uint64[] public preconfirmedTasks;
    bytes[] public preconfirmedTaskResults;
    mapping(uint64 => Task) public tasks;
    mapping(bytes32 => uint64) public taskRecords;

    function initialize(address _taskSubmitter, address _owner) public initializer {
        __Ownable_init(_owner);
        taskSubmitter = _taskSubmitter;
    }

    /**
     * @dev Set new task submitter.
     * @param _taskSubmitter The new task submitter contract address.
     */
    function setTaskSubmitter(address _taskSubmitter) external onlyOwner {
        require(_taskSubmitter != address(0), InvalidAddress());
        taskSubmitter = _taskSubmitter;
    }

    /**
     * @dev Get task state.
     * @param _taskId Id of the task.
     */
    function getTaskState(uint64 _taskId) external view returns (State) {
        return tasks[_taskId].state;
    }

    /**
     * @dev Get the latest task.
     */
    function getLatestTask() external view returns (Task memory) {
        require(nextTaskId > 0, EmptyTask());
        return tasks[nextTaskId - 1];
    }

    /**
     * @dev Get all uncompleted tasks.
     */
    function getUncompletedTasks() external view returns (Task[] memory) {
        return uncompletedTasks;
    }

    /**
     * @dev Add new task.
     * @param _submitter The submitter of the task.
     * @param _context The context of the task.
     */
    function submitTask(address _submitter, bytes calldata _context) external returns (uint64) {
        require(msg.sender == taskSubmitter, OnlyTaskSubmitter());

        bytes32 hash = keccak256(_context);
        uint64 taskId = taskRecords[hash];
        require(taskId == 0, AlreadyExistTask(taskId));
        taskId = nextTaskId++;
        Task memory newTask = Task({
            id: taskId,
            state: State.Created,
            submitter: _submitter,
            createdAt: block.timestamp,
            updatedAt: 0,
            context: _context,
            result: ""
        });
        tasks[taskId] = newTask;
        taskRecords[hash] = taskId;
        uncompletedTasks.push(newTask);

        emit TaskSubmitted(taskId, _context, _submitter);
        return taskId;
    }

    /**
     * @dev Update tast state.
     * @param _taskId Id of the task.
     * @param _state The new state of the tast.
     * @param _result (Optional) The final result of the task.
     */
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
        if (_state == State.Failed || _state == State.Completed) {
            for (uint32 i; i < uncompletedTasks.length; ++i) {
                if (uncompletedTasks[i].id == _taskId) {
                    uncompletedTasks[i] = uncompletedTasks[uncompletedTasks.length - 1];
                    uncompletedTasks.pop();
                    break;
                }
            }
        }
        task.state = _state;
        task.updatedAt = block.timestamp;
        if (_result.length > 0) {
            task.result = _result;
        }
        emit TaskUpdated(_taskId, task.submitter, block.timestamp, _state, _result);
    }
}
