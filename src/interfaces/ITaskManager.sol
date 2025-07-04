// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

enum State {
    Created,
    Pending,
    Processing,
    Completed,
    Failed
}

struct Task {
    State state;
    address handler;
    bytes32 dataHash;
}

interface ITaskManager {
    event TaskSubmitted(uint64[] taskIds, address indexed handler, bytes32[] dataHashs);
    event TaskUpdated(uint64[] taskIds, State[] state);

    error EmptyTask();
    error InvalidTask(uint64 taskId);

    function getTask(uint64) external view returns (Task memory);

    function getLatestTask() external view returns (Task memory);

    function getUncompletedTasks() external view returns (Task[] memory);

    function getTaskState(uint64 _taskId) external view returns (State);

    function submitTask(bytes32[] calldata _context) external returns (uint64[] memory);

    function updateTask(uint64[] calldata _taskId, State[] calldata _state) external;
}
