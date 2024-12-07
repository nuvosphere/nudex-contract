// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ITaskManager} from "../interfaces/ITaskManager.sol";

contract TaskSubmitterUpgradeable is OwnableUpgradeable {
    ITaskManager public immutable taskManager;

    mapping(uint8 taskType => address whitelist) public whitelists;

    constructor(address _taskManager) {
        taskManager = ITaskManager(_taskManager);
    }

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    function setWhitelist(uint8 _taskType, address _whitelist) external onlyOwner {
        require(_whitelist != address(0), "Invalid address");
        whitelists[_taskType] = _whitelist;
    }

    function submitTask(bytes calldata _context) external returns (uint64) {
        require(msg.sender == whitelists[uint8(bytes1(_context[0:2]))], "Only Whitelist");
        return taskManager.submitTask(msg.sender, _context);
    }
}
