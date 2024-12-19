// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IAssetHandler, AssetType} from "../interfaces/IAssetHandler.sol";
import {IFundsHandler} from "../interfaces/IFundsHandler.sol";
import {ITaskManager} from "../interfaces/ITaskManager.sol";
import {INIP20} from "../interfaces/INIP20.sol";

contract FundsHandlerUpgradeable is IFundsHandler, AccessControlUpgradeable {
    bytes32 public constant ENTRYPOINT_ROLE = keccak256("ENTRYPOINT_ROLE");
    bytes32 public constant SUBMITTER_ROLE = keccak256("SUBMITTER_ROLE");
    ITaskManager public immutable taskManager;
    IAssetHandler private immutable assetHandler;

    mapping(bytes32 pauseType => bool isPaused) public pauseState;
    mapping(address userAddr => DepositInfo[]) public deposits;
    mapping(address userAddr => WithdrawalInfo[]) public withdrawals;

    constructor(address _assetHandler, address _taskManager) {
        assetHandler = IAssetHandler(_assetHandler);
        taskManager = ITaskManager(_taskManager);
    }

    // _owner: EntryPoint contract
    function initialize(
        address _owner,
        address _entryPoint,
        address _submitter
    ) public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(ENTRYPOINT_ROLE, _entryPoint);
        _grantRole(SUBMITTER_ROLE, _submitter);
    }

    /**
     * @dev Get all deposit records of user.
     */
    function getDeposits(address userAddress) external view returns (DepositInfo[] memory) {
        require(userAddress != address(0), InvalidAddress());
        return deposits[userAddress];
    }

    /**
     * @dev Get n-th deposit record of user.
     */
    function getDeposit(
        address userAddress,
        uint256 index
    ) external view returns (DepositInfo memory) {
        require(userAddress != address(0), InvalidAddress());
        return deposits[userAddress][index];
    }

    /**
     * @dev Get all withdraw records of user.
     */
    function getWithdrawals(address userAddress) external view returns (WithdrawalInfo[] memory) {
        return withdrawals[userAddress];
    }

    /**
     * @dev Get n-th withdraw record of user.
     */
    function getWithdrawal(
        address userAddress,
        uint256 index
    ) external view returns (WithdrawalInfo memory) {
        require(userAddress != address(0), InvalidAddress());
        return withdrawals[userAddress][index];
    }

    // TODO: role for adjusting Pause state
    function setPauseState(bytes32 _condition, bool _newState) external onlyRole(ENTRYPOINT_ROLE) {
        pauseState[_condition] = _newState;
    }

    function submitDepositTask(
        address _userAddress,
        bytes32 _ticker,
        bytes32 _chainId,
        uint256 _amount
    ) external onlyRole(SUBMITTER_ROLE) returns (uint64) {
        require(!pauseState[_ticker] && !pauseState[bytes32(_chainId)], Paused());
        require(_amount >= assetHandler.getAssetDetails(_ticker).minDepositAmount, InvalidAmount());
        require(_userAddress != address(0), InvalidAddress());
        return
            taskManager.submitTask(
                msg.sender,
                abi.encodeWithSelector(
                    this.recordDeposit.selector,
                    _userAddress,
                    _ticker,
                    _chainId,
                    _amount
                )
            );
    }

    /**
     * @dev Record deposit info.
     */
    function recordDeposit(
        address _userAddress,
        bytes32 _ticker,
        bytes32 _chainId,
        uint256 _amount
    ) external onlyRole(ENTRYPOINT_ROLE) returns (bytes memory) {
        deposits[_userAddress].push(
            DepositInfo({
                userAddress: _userAddress,
                ticker: _ticker,
                chainId: _chainId,
                amount: _amount
            })
        );
        emit INIP20.NIP20TokenEvent_mintb(_userAddress, _ticker, _amount);
        emit DepositRecorded(_userAddress, _ticker, _chainId, _amount);
        return abi.encodePacked(uint8(1), _userAddress, _ticker, _chainId, _amount);
    }

    function submitWithdrawTask(
        address _userAddress,
        bytes32 _ticker,
        bytes32 _chainId,
        uint256 _amount,
        uint256 _btcAmount
    ) external onlyRole(SUBMITTER_ROLE) returns (uint64) {
        require(!pauseState[_ticker] && !pauseState[bytes32(_chainId)], Paused());
        require(_userAddress != address(0), InvalidAddress());
        bytes memory callData;
        if (_btcAmount == 0) {
            require(
                _amount >= assetHandler.getAssetDetails(_ticker).minWithdrawAmount,
                InvalidAmount()
            );
            callData = abi.encodeWithSelector(
                this.recordWithdrawal.selector,
                _userAddress,
                _ticker,
                _chainId,
                _amount,
                _btcAmount
            );
        } else {
            callData = abi.encodePacked(this.recordWithdrawal.selector);
        }
        emit INIP20.NIP20TokenEvent_burnb(_userAddress, _ticker, _amount);
        return taskManager.submitTask(msg.sender, callData);
    }

    /**
     * @dev Record withdraw info.
     */
    function recordWithdrawal(
        address _userAddress,
        bytes32 _ticker,
        bytes32 _chainId,
        uint256 _amount,
        uint256 _btcAmount
    ) external onlyRole(ENTRYPOINT_ROLE) returns (bytes memory) {
        withdrawals[_userAddress].push(
            WithdrawalInfo({
                userAddress: _userAddress,
                ticker: _ticker,
                chainId: _chainId,
                amount: _amount
            })
        );
        assetHandler.withdraw(_ticker, _chainId, _amount, _btcAmount);
        emit WithdrawalRecorded(_userAddress, _ticker, _chainId, _amount, _btcAmount);
        return abi.encodePacked(uint8(1), _userAddress, _ticker, _chainId, _amount, _btcAmount);
    }
}
