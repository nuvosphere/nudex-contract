// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ITaskManager} from "../interfaces/ITaskManager.sol";
import {INIP20} from "../interfaces/INIP20.sol";

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

    function setMinAmount(
        uint256 _dAmount,
        uint256 _wAmount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        minDepositAmount = _dAmount;
        minWithdrawAmount = _wAmount;
    }

    // force submit task by Admin
    function submitTask(
        bytes calldata _context
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint64) {
        return taskManager.submitTask(msg.sender, _context);
    }

    function submitDepositTask(
        address _user,
        uint256 _amount,
        bytes32 _ticker
    ) external onlyRole(FUNDS_ROLE) returns (uint64) {
        require(_amount >= minDepositAmount, "Below Min Deposit Amount.");
        return taskManager.submitTask(msg.sender, abi.encodePacked(_user, _amount, _ticker));
    }

    function submitWithdrawTask(
        address _user,
        uint256 _amount,
        bytes32 _ticker
    ) external onlyRole(FUNDS_ROLE) returns (uint64) {
        require(_amount >= minWithdrawAmount, "Below Min Withdraw Amount.");
        emit INIP20.NIP20TokenEvent_burnb(_user, _ticker, _amount);
        return taskManager.submitTask(_user, abi.encodePacked(_user, _amount, _ticker));
    }
}
