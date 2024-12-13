// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

enum State {
    Created,
    Pending,
    Completed,
    Failed
}

struct TaskOperation {
    uint64 id;
    State state;
    address submitter;
    address handler;
    uint32 createdAt;
    uint32 updatedAt;
    bytes optData;
    bytes result;
}

interface ITaskManager {
    event TaskSubmitted(uint64 indexed taskId, address indexed submitter, bytes data);
    event TaskUpdated(
        uint64 indexed taskId,
        address indexed submitter,
        uint256 indexed updateTime,
        State state,
        bytes result
    );

    error EmptyTask();
    error OnlyTaskSubmitter();
    error InvalidTask(uint64 taskId);
    error InvalidPendingTask(uint64 taskId);
    error AlreadyExistTask(uint64 taskId);
    error InvalidAddress();

    function getLatestTask() external view returns (TaskOperation memory);

    function getUncompletedTasks() external view returns (TaskOperation[] memory);

    function getTaskState(uint64 _taskId) external view returns (State);

    function submitTask(
        address _submitter,
        address _handler,
        bytes calldata _context
    ) external returns (uint64);

    function updateTask(uint64 _taskId, State _state, bytes calldata _result) external;
}
