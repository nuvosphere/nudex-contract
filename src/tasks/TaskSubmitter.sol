// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ITaskManager} from "../interfaces/ITaskManager.sol";

contract TaskSubmitter {
    ITaskManager public taskManager;

    constructor(address _taskManager) {
        taskManager = ITaskManager(_taskManager);
    }

    function submitTask(bytes calldata _context) external returns (uint64) {
        return taskManager.submitTask(msg.sender, _context);
    }
}
