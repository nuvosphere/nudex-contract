// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ITaskManager} from "../interfaces/ITaskManager.sol";

contract TaskSubmitterUpgradeable is AccessControlUpgradeable {
    ITaskManager public immutable taskManager;

    constructor(address _taskManager) {
        taskManager = ITaskManager(_taskManager);
    }

    function initialize(address _owner) public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        __AccessControl_init();
    }

    // force submit task by Admin
    function forceSubmitTask(
        bytes calldata _data
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint64) {
        return taskManager.submitTask(address(0), _data);
    }
}
