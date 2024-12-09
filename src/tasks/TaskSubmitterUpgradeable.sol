// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ITaskManager} from "../interfaces/ITaskManager.sol";
import {INIP20} from "../interfaces/INIP20.sol";

contract TaskSubmitterUpgradeable is AccessControlUpgradeable {
    bytes32 public constant FUNDS_ROLE = keccak256("FUNDS_ROLE");
    bytes32 public constant ACCOUNT_ROLE = keccak256("ACCOUNT_ROLE");
    bytes32 public constant DEX_ROLE = keccak256("DEX_ROLE");

    ITaskManager public immutable taskManager;

    uint256 public minDepositAmount;
    uint256 public minWithdrawAmount;
    mapping(bytes32 pauseType => bool isPaused) public pauseState;

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

    function setPauseState(bytes32 _condition, bool _newState) external onlyRole(DEX_ROLE) {
        pauseState[_condition] = _newState;
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
        bytes32 _ticker,
        uint256 _chainId
    ) external onlyRole(FUNDS_ROLE) returns (uint64) {
        require(!pauseState[_ticker] && !pauseState[bytes32(_chainId)], "Paused");
        require(_amount >= minDepositAmount, "Below Min Deposit Amount.");
        return
            taskManager.submitTask(msg.sender, abi.encodePacked(_user, _amount, _ticker, _chainId));
    }

    function submitWithdrawTask(
        address _user,
        uint256 _amount,
        bytes32 _ticker,
        uint256 _chainId
    ) external onlyRole(FUNDS_ROLE) returns (uint64) {
        require(!pauseState[_ticker] && !pauseState[bytes32(_chainId)], "Paused");
        require(_amount >= minWithdrawAmount, "Below Min Withdraw Amount.");
        emit INIP20.NIP20TokenEvent_burnb(_user, _ticker, _amount);
        return taskManager.submitTask(_user, abi.encodePacked(_user, _amount, _ticker, _chainId));
    }

    function submitAccountCreationTask() external onlyRole(ACCOUNT_ROLE) returns (uint64) {}

    function submitParticipantUpdateTask() external onlyRole(ACCOUNT_ROLE) returns (uint64) {}

    function submitConsolidateTask() external onlyRole(DEX_ROLE) returns (uint64) {}
}
