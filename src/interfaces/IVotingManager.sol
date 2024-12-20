// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {State} from "../interfaces/ITaskManager.sol";

struct Operation {
    address managerAddr; // 20 bytes
    State state; // 1 byte
    uint64 taskId; // 8 bytes
    bytes optData;
}

contract IVotingManager {
    event SubmitterChosen(address indexed newSubmitter);
    event SubmitterRotationRequested(address indexed requester, address indexed currentSubmitter);
    event OperationFailed(bytes indexed errInfo);

    error EmptyOperationsArray();
    error InvalidSigner(address sender);
    error IncorrectSubmitter(address sender, address submitter);
    error RotationWindowNotPassed(uint256 current, uint256 window);
    error TaskAlreadyCompleted(uint256 taskId);
    error InvalidAddress();
}
