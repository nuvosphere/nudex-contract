// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ITaskManager {
    enum State {
        Created,
        Pending,
        Completed,
        Failed
    }

    struct Task {
        uint256 id;
        State state;
        address submitter;
        uint256 createdAt;
        uint256 updatedAt;
        bytes context;
        bytes result;
    }

    event TaskSubmitted(uint256 indexed taskId, bytes context, address indexed submitter);
    event TaskUpdated(
        uint256 indexed taskId,
        address indexed submitter,
        uint256 indexed updateTime,
        bytes result
    );

    error EmptyTask();
    error OnlyTaskSubmitter();

    function submitTask(address _submitter, bytes calldata _context) external returns (uint256);

    function getLatestTask() external view returns (Task memory);

    function updateTask(uint256 _taskId, State _state, bytes calldata _result) external;

    function getUncompletedTasks() external view returns (Task[] memory);

    function getTaskState(uint256 taskId) external view returns (State);
}
