// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INuDexOperations {
    struct Task {
        uint256 id;
        string description;
        address submitter;
        bool isCompleted;
        uint256 createdAt;
        uint256 completedAt;
        bytes result;
    }

    event TaskSubmitted(uint256 indexed taskId, string description, address indexed submitter);
    event TaskCompleted(
        uint256 indexed taskId,
        address indexed submitter,
        uint256 indexed completedAt,
        bytes result
    );

    error EmptyTask();

    function submitTask(string memory description) external;

    function getLatestTask() external view returns (Task memory);

    function markTaskCompleted(uint256 taskId, bytes calldata result) external;

    function getUncompletedTasks() external view returns (Task[] memory);

    function isTaskCompleted(uint256 taskId) external view returns (bool);
}
