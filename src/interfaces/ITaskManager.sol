// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ITaskManager {
    struct Task {
        uint256 id;
        bytes context;
        address submitter;
        bool isCompleted;
        uint256 createdAt;
        uint256 completedAt;
        bytes result;
    }

    event TaskSubmitted(uint256 indexed taskId, bytes context, address indexed submitter);
    event TaskCompleted(
        uint256 indexed taskId,
        address indexed submitter,
        uint256 indexed completedAt,
        bytes result
    );

    error EmptyTask();
    error OnlyTaskSubmitter();

    function submitTask(address _submitter, bytes calldata _context) external returns (uint256);

    function getLatestTask() external view returns (Task memory);

    function markTaskCompleted(uint256 taskId, bytes calldata result) external;

    function markTaskCompleted_Batch(
        uint256[] calldata _taskIds,
        bytes[] calldata _results
    ) external;

    function preconfirmTask(uint256 _taskId, bytes calldata _result) external;

    function confirmAllTasks() external;

    function getUncompletedTasks() external view returns (Task[] memory);

    function isTaskCompleted(uint256 taskId) external view returns (bool);
}