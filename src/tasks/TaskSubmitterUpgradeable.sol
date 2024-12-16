// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IAccountHandler} from "../interfaces/IAccountHandler.sol";
import {IFundsHandler} from "../interfaces/IFundsHandler.sol";
import {ITaskManager} from "../interfaces/ITaskManager.sol";
import {INIP20} from "../interfaces/INIP20.sol";

contract TaskSubmitterUpgradeable is AccessControlUpgradeable {
    bytes32 public constant FUNDS_ROLE = keccak256("FUNDS_ROLE");
    bytes32 public constant ACCOUNT_ROLE = keccak256("ACCOUNT_ROLE");
    bytes32 public constant DEX_ROLE = keccak256("DEX_ROLE");

    ITaskManager public immutable taskManager;
    address public immutable accountHandler;
    address public immutable assetHandler;
    address public immutable fundsHandler;
    address public immutable participantHandler;

    uint256 public minDepositAmount;
    uint256 public minWithdrawAmount;
    mapping(bytes32 pauseType => bool isPaused) public pauseState;

    constructor(
        address _taskManager,
        address _accountHandler,
        address _assetHandler,
        address _fundsHandler,
        address _participantHandler
    ) {
        taskManager = ITaskManager(_taskManager);
        accountHandler = _accountHandler;
        assetHandler = _assetHandler;
        fundsHandler = _fundsHandler;
        participantHandler = _participantHandler;
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
    function forceSubmitTask(
        address _handler,
        bytes calldata _data
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint64) {
        return taskManager.submitTask(msg.sender, _handler, _data);
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
            taskManager.submitTask(
                msg.sender,
                fundsHandler,
                abi.encodeWithSelector(
                    IFundsHandler.recordDeposit.selector,
                    _user,
                    _ticker,
                    _chainId,
                    _amount
                )
            );
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
        return
            taskManager.submitTask(
                msg.sender,
                fundsHandler,
                abi.encodeWithSelector(
                    IFundsHandler.recordWithdrawal.selector,
                    _user,
                    _ticker,
                    _chainId,
                    _amount
                )
            );
    }

    function submitAccountCreationTask(
        uint256 _account,
        IAccountHandler.Chain _chain,
        uint256 _index,
        string calldata _address
    ) external onlyRole(ACCOUNT_ROLE) returns (uint64) {
        require(bytes(_address).length != 0, "InvalidAddress()");
        require(_account > 10000, "InvalidAccountNumber(_account)");
        return
            taskManager.submitTask(
                msg.sender,
                accountHandler,
                abi.encodeWithSelector(
                    IAccountHandler.registerNewAddress.selector,
                    _account,
                    _chain,
                    _index,
                    _address
                )
            );
    }

    function submitParticipantUpdateTask() external onlyRole(ACCOUNT_ROLE) returns (uint64) {}

    function submitConsolidateTask() external onlyRole(DEX_ROLE) returns (uint64) {}
}
