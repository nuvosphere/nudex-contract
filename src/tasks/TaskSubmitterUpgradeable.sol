// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ITaskManager} from "../interfaces/ITaskManager.sol";

contract TaskSubmitterUpgradeable is AccessControlUpgradeable {
    bytes32 public constant FUNDS_ROLE = keccak256("FUNDS_ROLE");

    ITaskManager public immutable taskManager;

    uint256 public minDepositAmount;
    uint256 public minWithdrawAmount;

    constructor(address _taskManager) {
        taskManager = ITaskManager(_taskManager);
    }

    function initialize(address _owner) public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        __AccessControl_init();
    }

    function submitTask(
        bytes calldata _context
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint64) {
        return taskManager.submitTask(msg.sender, _context);
    }

    function submitDepositTask(
        bytes calldata _context
    ) external onlyRole(FUNDS_ROLE) returns (uint64) {
        require(uint256(bytes32(_context[0:64])) >= minDepositAmount, "Below Min Deposit Amount.");
        return taskManager.submitTask(msg.sender, _context);
    }

    function submitWithdrawTask(
        bytes calldata _context
    ) external onlyRole(FUNDS_ROLE) returns (uint64) {
        require(
            uint256(bytes32(_context[0:64])) >= minWithdrawAmount,
            "Below Min Withdraw Amount."
        );
        return taskManager.submitTask(msg.sender, _context);
    }
}
