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

    IAccountHandler public immutable accountHandler;
    IAssetManager public immutable assetHandler;

    address public feeReceiver;
    mapping(bytes32 => uint256) public totalValueLocked;
    mapping(bytes32 userHash => uint256[] depositAmounts) private deposits;
    mapping(bytes32 userHash => uint256[] withdrawAmounts) private withdrawals;

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
        address _feeReceiver
    ) public initializer {
        __HandlerBase_init(_owner, _entryPoint, _submitter);
        _grantRole(TRACKER_ROLE, _trackerAddress);
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
        taskIds = new uint64[](_params.length);
        bytes32[] memory dataHashes = new bytes32[](_params.length);
        uint256[] memory tokenAmounts = new uint256[](_params.length);
        uint256[] memory withdrawFees = new uint256[](_params.length);
        NudexAsset memory nudexAsset;
        TokenInfo memory tokenInfo;
        for (uint256 i; i < _params.length; i++) {
            require(
                assetHandler.isAssetAllowed(_params[i].ticker, _params[i].chainId),
                "Asset not allowed"
            );
            nudexAsset = assetHandler.getAssetDetails(_params[i].ticker);

            // check min withdraw amount
            require(_params[i].amount >= nudexAsset.minWithdrawAmount, "Invalid amount");

            // validate toAddress
            uint256 addrLength = bytes(_params[i].toAddress).length;
            require(addrLength > 0, "Invalid address");

            // check fee
            tokenInfo = assetHandler.getLinkedToken(_params[i].ticker, _params[i].chainId);
            withdrawFees[i] = tokenInfo.withdrawFee; // nudex decimals
            require(withdrawFees[i] < _params[i].amount, "Insufficient balance to pay fee");

            // deduct asset balance from user's account
            emit INIP20.NIP20TokenEvent_burnb(
                accountHandler.getUserAddress(_params[i].accountNumber),
                _params[i].ticker,
                _params[i].amount
            );

            // calculate the actual withdraw amount on target chain
            tokenAmounts[i] = (((_params[i].amount - withdrawFees[i]) *
                (10 ** tokenInfo.decimals)) / (10 ** nudexAsset.decimals));

            dataHashes[i] = keccak256(
                abi.encodeWithSelector(
                    this.recordWithdrawal.selector,
                    _params[i].accountNumber,
                    _params[i].chainId,
                    _params[i].ticker,
                    _params[i].toAddress,
                    _params[i].amount,
                    withdrawFees[i],
                    _params[i].salt,
                    // offset for txHash
                    // @dev "-1" if it is exact 32 bytes it does not take one extra slot
                    uint256(320) + (32 * ((addrLength - 1) / 32))
                )
            );
        }
        taskIds = taskManager.submitTask(dataHashes);
        emit WithdrawRequest(dataHashes, tokenAmounts, withdrawFees);
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
    ) external onlyRole(SUBMITTER_ROLE) returns (uint64[] memory taskIds) {
        taskIds = new uint64[](_params.length);
        bytes32[] memory dataHashes = new bytes32[](_params.length);
        for (uint256 i; i < _params.length; i++) {
            require(_params[i].amount > 0, "Invalid amount");
            uint256 fromAddrLength = bytes(_params[i].fromAddress).length;
            uint256 toAddrLength = bytes(_params[i].toAddress).length;
            require(fromAddrLength > 0 && toAddrLength > 0, "Invalid address");
            dataHashes[i] = keccak256(abi.encode(_params[i]));
        }
        taskIds = taskManager.submitTask(dataHashes);
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
