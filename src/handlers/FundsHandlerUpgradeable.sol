// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {HandlerBase} from "./HandlerBase.sol";
import {IAccountHandler} from "../interfaces/IAccountHandler.sol";
import {IAssetManager, NudexAsset, TokenInfo} from "../interfaces/IAssetManager.sol";
import {IFundsHandler, AddressCategory, DepositParam, WithdrawalParam, TransferParam, ConsolidateTaskParam} from "../interfaces/IFundsHandler.sol";
import {INIP20} from "../interfaces/INIP20.sol";
// import {console} from "forge-std/console.sol";

contract FundsHandlerUpgradeable is IFundsHandler, HandlerBase {
    bytes32 public constant TRACKER_ROLE = keccak256("TRACKER_ROLE");
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

    IAccountHandler public immutable accountHandler;
    IAssetManager public immutable assetHandler;

    // Pending withdrawals are stored as a queue using a start index to avoid costly shifts
    bytes32[] private pendingWithdrawalHashes;
    uint256 private pendingWithdrawalStart;

    address public feeReceiver;
    mapping(bytes32 => uint256) public totalValueLocked;
    mapping(bytes32 userHash => uint256[] depositAmounts) private deposits;
    mapping(bytes32 userHash => uint256[] withdrawAmounts) private withdrawals;
    mapping(uint64 parentTaskId => uint64 childTaskId) public parentToChildTasks;

    constructor(
        address _accountHandler,
        address _assetHandler,
        address _taskManager
    ) HandlerBase(_taskManager) {
        accountHandler = IAccountHandler(_accountHandler);
        assetHandler = IAssetManager(_assetHandler);
    }

    function initialize(
        address _owner,
        address _entryPoint,
        address _submitter,
        address _trackerAddress,
        address _transferAddress,
        address _feeReceiver
    ) public initializer {
        __HandlerBase_init(_owner, _entryPoint, _submitter);
        _grantRole(TRACKER_ROLE, _trackerAddress);
        _grantRole(TRANSFER_ROLE, _transferAddress);
        feeReceiver = _feeReceiver;
    }

    /**
     * @dev Get all deposit records of user.
     */
    function getDeposits(
        uint32 _accountNumber,
        bytes32 _ticker,
        uint64 _chainId
    ) external view returns (uint256[] memory) {
        return deposits[keccak256(abi.encodePacked(_accountNumber, _ticker, _chainId))];
    }

    /**
     * @dev Get n-th deposit record of user.
     */
    function getDeposit(
        uint32 _accountNumber,
        bytes32 _ticker,
        uint64 _chainId,
        uint256 _index
    ) external view returns (uint256) {
        return deposits[keccak256(abi.encodePacked(_accountNumber, _ticker, _chainId))][_index];
    }

    /**
     * @dev Get all withdraw records of user.
     */
    function getWithdrawals(
        uint32 _accountNumber,
        bytes32 _ticker,
        uint64 _chainId
    ) external view returns (uint256[] memory) {
        return withdrawals[keccak256(abi.encodePacked(_accountNumber, _ticker, _chainId))];
    }

    /**
     * @dev Get n-th withdraw record of user.
     */
    function getWithdrawal(
        uint32 _accountNumber,
        bytes32 _ticker,
        uint64 _chainId,
        uint256 _index
    ) external view returns (uint256) {
        return withdrawals[keccak256(abi.encodePacked(_accountNumber, _ticker, _chainId))][_index];
    }

    /**
     * @dev Set the fee receiver address.
     */
    function setFeeReceiver(address _feeReceiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_feeReceiver != address(0), "Invalid address");
        feeReceiver = _feeReceiver;
        emit FeeReceiverUpdated(_feeReceiver);
    }

    /**
     * @dev Submit deposit task.
     * @param _params The task parameters.
     * userAddress The EVM address of the user.
     * depositAddress The deposit address assigned to the user.
     * ticker The ticker of the asset.
     * chainId The chain id of the asset.
     * amount The amount to deposit.
     */
    function submitDepositTask(
        DepositParam[] calldata _params
    ) external onlyRole(TRACKER_ROLE) returns (uint64[] memory taskIds) {
        require(_params.length > 0, "Empty input");
        taskIds = new uint64[](_params.length);
        bytes32[] memory dataHashes = new bytes32[](_params.length);
        for (uint256 i; i < _params.length; i++) {
            require(
                assetHandler.isAssetAllowed(_params[i].ticker, _params[i].chainId),
                "Asset not allowed"
            );
            require(
                _params[i].amount >=
                    assetHandler.getAssetDetails(_params[i].ticker).minDepositAmount,
                "Invalid amount"
            );
            dataHashes[i] = keccak256(
                abi.encodeWithSelector(this.recordDeposit.selector, _params[i])
            );
        }
        taskIds = taskManager.submitTask(dataHashes);
    }

    /**
     * @dev Record deposit info.
     */
    function recordDeposit(DepositParam calldata _param) external onlyRole(ENTRYPOINT_ROLE) {
        require(assetHandler.isAssetAllowed(_param.ticker, _param.chainId), "Asset not allowed");
        deposits[keccak256(abi.encodePacked(_param.accountNumber, _param.ticker, _param.chainId))]
            .push(_param.amount);
        totalValueLocked[_param.ticker] += _param.amount;
        emit INIP20.NIP20TokenEvent_mintb(
            accountHandler.getUserAddress(_param.accountNumber),
            _param.ticker,
            _param.amount
        );
    }

    /**
     * @dev Submit withdraw task.
     * @param _params The task parameters.
     * userAddress The EVM address of the user.
     * depositAddress The deposit address assigned to the user.
     * ticker The ticker of the asset.
     * chainId The chain id of the asset.
     * amount The amount to deposit.
     * salt The salt for withdrawal.
     */
    function submitWithdrawTask(
        WithdrawalParam[] calldata _params
    ) external onlyRole(SUBMITTER_ROLE) returns (uint64[] memory taskIds) {
        require(_params.length > 0, "Empty input");

        // First pass: validate basic conditions and count eligible submissions (not requiring review)
        uint256 eligibleCount;
        for (uint256 i; i < _params.length; i++) {
            require(
                assetHandler.isAssetAllowed(_params[i].ticker, _params[i].chainId),
                "Asset not allowed"
            );

            NudexAsset memory assetInfoFirstPass = assetHandler.getAssetDetails(_params[i].ticker);

            // check min withdraw amount
            require(_params[i].amount >= assetInfoFirstPass.minWithdrawAmount, "Invalid amount");

            // validate toAddress
            require(bytes(_params[i].toAddress).length > 0, "Invalid address");

            // count only those not exceeding review threshold (0 disables review)
            if (
                assetInfoFirstPass.withdrawReviewThreshold == 0 ||
                _params[i].amount <= assetInfoFirstPass.withdrawReviewThreshold
            ) {
                unchecked {
                    eligibleCount++;
                }
            }
        }

        // Allocate arrays sized to the number of eligible submissions
        taskIds = new uint64[](eligibleCount);
        bytes32[] memory dataHashes = new bytes32[](eligibleCount);
        uint256[] memory tokenAmounts = new uint256[](eligibleCount);
        uint256[] memory withdrawFees = new uint256[](eligibleCount);

        // Second pass: build tasks or enqueue pending withdrawals for review
        uint256 writeIndex;
        for (uint256 i; i < _params.length; i++) {
            NudexAsset memory nudexAsset = assetHandler.getAssetDetails(_params[i].ticker);

            // validate toAddress and compute its length for txHash offset
            uint256 addrLength = bytes(_params[i].toAddress).length;
            require(addrLength > 0, "Invalid address");

            // fetch token info and fee
            TokenInfo memory tokenInfo = assetHandler.getLinkedToken(
                _params[i].ticker,
                _params[i].chainId
            );
            uint256 feeAmount = tokenInfo.withdrawFee; // nudex decimals
            require(feeAmount < _params[i].amount, "Insufficient balance to pay fee");

            // prepare data hash
            bytes32 dh = keccak256(
                abi.encodeWithSelector(
                    this.recordWithdrawal.selector,
                    _params[i].accountNumber,
                    _params[i].chainId,
                    _params[i].ticker,
                    _params[i].toAddress,
                    _params[i].amount,
                    feeAmount,
                    _params[i].salt,
                    // offset for txHash
                    // @dev "-1" if it is exact 32 bytes it does not take one extra slot
                    uint256(320) + (32 * ((addrLength - 1) / 32))
                )
            );

            // deduct asset balance from user's account only for submitted tasks
            emit INIP20.NIP20TokenEvent_burnb(
                accountHandler.getUserAddress(_params[i].accountNumber),
                _params[i].ticker,
                _params[i].amount
            );

            uint256 tokenAmount = (((_params[i].amount - feeAmount) * (10 ** tokenInfo.decimals)) /
                (10 ** nudexAsset.decimals));
            // If amount exceeds review threshold (and threshold enabled), enqueue to pending and skip submission
            if (
                nudexAsset.withdrawReviewThreshold > 0 &&
                _params[i].amount > nudexAsset.withdrawReviewThreshold
            ) {
                pendingWithdrawalHashes.push(dh);
                emit PendingWithdrawal(dh, tokenAmount, feeAmount);
                continue;
            }

            // calculate the actual withdraw amount on target chain
            tokenAmounts[writeIndex] = tokenAmount;

            withdrawFees[writeIndex] = feeAmount;
            dataHashes[writeIndex] = dh;
            unchecked {
                writeIndex++;
            }
        }

        if (eligibleCount > 0) {
            taskIds = taskManager.submitTask(dataHashes);
            emit WithdrawRequest(dataHashes, tokenAmounts, withdrawFees);
        }
    }

    /**
     * @dev Submit pending withdrawals to the task manager.
     * @param _expectedPendingCount If non-zero, the current pending count
     * must equal this value, otherwise the call reverts. This helps avoid unexpectedly including
     * newly enqueued items because of mempool reordering.
     */
    function submitPendingWithdrawals(
        uint256 _expectedPendingCount
    ) external onlyRole(SUBMITTER_ROLE) returns (uint64[] memory taskIds) {
        uint256 currentCount = pendingWithdrawalHashes.length - pendingWithdrawalStart;
        require(currentCount > 0, "No pending withdrawals");
        uint256 toSubmit = _expectedPendingCount == 0 ? currentCount : _expectedPendingCount;
        if (_expectedPendingCount != 0) {
            require(currentCount == _expectedPendingCount, "Pending size changed");
        }

        bytes32[] memory dataHashes = new bytes32[](toSubmit);
        for (uint256 j; j < toSubmit; j++) {
            dataHashes[j] = pendingWithdrawalHashes[pendingWithdrawalStart + j];
        }

        taskIds = taskManager.submitTask(dataHashes);
        emit PendingWithdrawalsSubmitted(dataHashes);

        // advance the start index and optionally compact storage
        pendingWithdrawalStart += toSubmit;
        if (pendingWithdrawalStart == pendingWithdrawalHashes.length) {
            delete pendingWithdrawalHashes;
            pendingWithdrawalStart = 0;
        }
    }

    /**
     * @dev Record withdraw info.
     */
    function recordWithdrawal(
        uint32 _accountNumber,
        uint64 _chainId,
        bytes32 _ticker,
        string calldata _toAddress,
        uint256 _amount,
        uint256 _withdrawFee,
        bytes32 _salt, // (not used)
        string calldata _txHash // (not used)
    ) external onlyRole(ENTRYPOINT_ROLE) {
        require(assetHandler.isAssetAllowed(_ticker, _chainId), "Asset not allowed");
        withdrawals[keccak256(abi.encodePacked(_accountNumber, _ticker, _chainId))].push(_amount);
        totalValueLocked[_ticker] -= _amount;
        emit INIP20.NIP20TokenEvent_mintb(feeReceiver, _ticker, _withdrawFee);
    }

    /**
     * @dev Submit a task to transfer asset
     * @param _params The task parameters
     * bytes32 ticker The asset ticker
     * uint64 chainId The chain id
     * string fromAddress The address to transfer from
     * string toAddress The address to transfer to
     * uint256 amount The amount to transfer
     */
    function submitTransferTask(
        TransferParam[] calldata _params
    ) external onlyRole(TRANSFER_ROLE) returns (uint64[] memory taskIds) {
        taskIds = new uint64[](_params.length);
        bytes32[] memory dataHashes = new bytes32[](_params.length);
        for (uint256 i; i < _params.length; i++) {
            require(_params[i].amount > 0, "Invalid amount");
            uint256 fromAddrLength = bytes(_params[i].fromAddress).length;
            uint256 toAddrLength = bytes(_params[i].toAddress).length;
            require(fromAddrLength > 0 && toAddrLength > 0, "Invalid address");
            require(parentToChildTasks[_params[i].parentTaskId] == 0, "Parent task id not allowed");
            dataHashes[i] = keccak256(abi.encode(_params[i]));
        }
        taskIds = taskManager.submitTask(dataHashes);
        for (uint256 i; i < taskIds.length; i++) {
            // link the parent task id to child task id
            if (_params[i].parentTaskId > 0) {
                parentToChildTasks[_params[i].parentTaskId] = taskIds[i];
            }
        }
    }

    /**
     * @dev Submit a task to consolidate the asset
     * @param _params The task parameters
     * address[] fromAddr The addresses to consolidate from
     * bytes32 ticker The asset ticker
     * uint64 chainId The chain id
     * uint64 chainIdTo The chain id of destination chain (if cross chain)
     * uint256 amount The amount to consolidate
     */
    function submitConsolidateTask(
        ConsolidateTaskParam[] calldata _params
    ) external onlyRole(TRACKER_ROLE) returns (uint64[] memory taskIds) {
        taskIds = new uint64[](_params.length);
        bytes32[] memory dataHashes = new bytes32[](_params.length);
        NudexAsset memory nudexAsset;
        for (uint256 i; i < _params.length; i++) {
            nudexAsset = assetHandler.getAssetDetails(_params[i].ticker);
            require(
                _params[i].amount >=
                    // convert the amount to match the token's decimals
                    ((nudexAsset.minDepositAmount *
                        (10 **
                            assetHandler
                                .getLinkedToken(_params[i].ticker, _params[i].chainIdFrom)
                                .decimals)) / (10 ** nudexAsset.decimals)),
                "Invalid amount"
            );
            uint256 addrLength = bytes(_params[i].fromAddress).length;
            require(addrLength > 0, "Invalid address");
            dataHashes[i] = keccak256(abi.encode(_params[i]));
        }
        taskIds = taskManager.submitTask(dataHashes);
    }
}
