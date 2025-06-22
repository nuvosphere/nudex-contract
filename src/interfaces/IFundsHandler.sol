// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AddressCategory} from "./IAccountHandler.sol";

struct DepositParam {
    uint32 accountNumber;
    uint64 chainId;
    AddressCategory addressCategory;
    bytes32 ticker;
    uint256 amount;
    string txHash;
    uint256 blockHeight;
    uint256 logIndex;
}

struct WithdrawalParam {
    uint32 accountNumber;
    uint64 chainId;
    AddressCategory addressCategory;
    bytes32 ticker;
    string toAddress;
    uint256 amount;
    bytes32 salt;
}

struct TransferParam {
    string fromAddress;
    string toAddress;
    bytes32 ticker;
    uint64 chainId;
    uint256 amount;
    bytes32 salt;
    bytes optionalData;
}

struct ConsolidateTaskParam {
    string fromAddress;
    bytes32 ticker;
    uint64 chainIdFrom;
    uint64 chainIdTo; // optional for cross chain
    uint256 amount;
    bytes32 salt;
}

interface IFundsHandler {
    event FeeReceiverUpdated(address newFeeReceiver);
    event WithdrawRequest(bytes32[] dataHashes, uint256[] tokenAmount, uint256[] feeAmount);

    event RequestTransfer(uint64[] taskIds, TransferParam[] params);
    event Transfer(
        bytes32 indexed ticker,
        uint64 indexed chainId,
        string fromAddress,
        string toAddress,
        uint256 amount,
        string txHash
    );
    event RequestConsolidate(uint64[] taskIds, ConsolidateTaskParam[] params);
    event Consolidate(
        bytes32 indexed ticker,
        uint64 indexed chainId,
        string fromAddress,
        uint256 amount,
        string txHash
    );
}
