// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ITaskManager, State, Task} from "./interfaces/ITaskManager.sol";

contract TaskManagerUpgradeable is ITaskManager, AccessControlUpgradeable {
    bytes32 public constant ENTRYPOINT_ROLE = keccak256("ENTRYPOINT_ROLE");
    bytes32 public constant HANDLER_ROLE = keccak256("HANDLER_ROLE");
    uint256 public constant MAX_BATCH_SIZE = 200;

    uint64 public nextTaskId;
    mapping(uint64 taskId => Task) public tasks;
    mapping(bytes32 hash => uint64 taskId) public taskHashes;

    function initialize(
        address _owner,
        address _entryPoint,
        address[] calldata _taskHandlers
    ) public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(ENTRYPOINT_ROLE, _entryPoint);
        for (uint8 i; i < _taskHandlers.length; ++i) {
            _grantRole(HANDLER_ROLE, _taskHandlers[i]);
        }

        nextTaskId = 1;
    }

    function getTask(uint64 _taskId) external view returns (Task memory) {
        return tasks[_taskId];
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
        Task[] memory tempTasks = new Task[](nextTaskId);
        uint256 count = 0;
        for (uint64 i = 0; i < nextTaskId; i++) {
            if (tasks[i].state != State.Completed) {
                tempTasks[count] = tasks[i];
                count++;
            }
        }
        Task[] memory uncompletedTasks = new Task[](count);
        for (uint256 i = 0; i < count; i++) {
            uncompletedTasks[i] = tempTasks[i];
        }

        return uncompletedTasks;
    }

    /**
     * @dev Add new task.
     * @param _dataHash The context of the task.
     */
    function submitTask(bytes32 _dataHash) external onlyRole(HANDLER_ROLE) returns (uint64 taskId) {
        require(taskHashes[_dataHash] == 0, "Duplicate task");
        taskId = nextTaskId++;
        tasks[taskId] = Task({state: State.Created, handler: msg.sender, dataHash: _dataHash});
        taskHashes[_dataHash] = taskId;

        emit TaskSubmitted(taskId, msg.sender, _dataHash);
    }

    function submitTaskBatch(
        bytes32[] calldata _dataHashes
    ) external onlyRole(HANDLER_ROLE) returns (uint64[] memory taskIds) {
        require(_dataHashes.length <= MAX_BATCH_SIZE, "Exceed max batch size");
        taskIds = new uint64[](_dataHashes.length);
        for (uint8 i; i < _dataHashes.length; ++i) {
            require(taskHashes[_dataHashes[i]] == 0, "Duplicate task");
            taskIds[i] = nextTaskId++;
            tasks[taskIds[i]] = Task({
                state: State.Created,
                handler: msg.sender,
                dataHash: _dataHashes[i]
            });
            taskHashes[_dataHashes[i]] = taskIds[i];
        }
        emit TaskSubmittedBatch(taskIds, msg.sender, _dataHashes);
    }

    function updateTaskBatch(
        uint64[] calldata _taskIds,
        State[] calldata _states
    ) external onlyRole(ENTRYPOINT_ROLE) {
        Task storage task;
        for (uint8 i; i < _taskIds.length; ++i) {
            task = tasks[_taskIds[i]];
            require(task.state != State.Completed && task.state != State.Failed, "Task finalized");
            task.state = _states[i];
            // TODO: reset dataHash if task failed?
            // if (_state == State.Failed) {
            //     taskHashes[_dataHashes[i]] = 0;
            // }
        }
        emit TaskUpdatedBatch(_taskIds, _states, uint32(block.timestamp));
    }
}
