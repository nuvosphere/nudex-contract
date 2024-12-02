// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

enum State {
    Created,
    Pending,
    Completed,
    Failed
}

interface ITaskManager {
    struct Task {
        uint64 id;
        State state;
        address submitter;
        uint256 createdAt;
        uint256 updatedAt;
        bytes context;
        bytes result;
    }

    event TaskSubmitted(uint64 indexed taskId, bytes context, address indexed submitter);
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

    function submitTask(address _submitter, bytes calldata _context) external returns (uint64);

    function getLatestTask() external view returns (Task memory);

    function updateTask(uint64 _taskId, State _state, bytes calldata _result) external;

    function getUncompletedTasks() external view returns (Task[] memory);

    function getTaskState(uint64 _taskId) external view returns (State);
}
