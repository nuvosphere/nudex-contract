// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockNuDexOperations {

    struct Task {
        uint256 id;
        string description;
        address submitter;
        bool isCompleted;
        uint256 createdAt;
        uint256 completedAt;
        bytes result;
    }

    function getUncompletedTasks() external view returns (Task[] memory) {
        return new Task[](0);
    }

}
