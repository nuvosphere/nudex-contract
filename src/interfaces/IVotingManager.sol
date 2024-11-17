// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ITaskManager} from "../interfaces/ITaskManager.sol";

contract IVotingManager {
    struct Operation {
        address managerAddr; // 20 bytes
        ITaskManager.Status status; // 1 byte
        uint64 taskId; // 8 bytes
        bytes optData;
    }

    event SubmitterChosen(address indexed newSubmitter);
    event SubmitterRotationRequested(address indexed requester, address indexed currentSubmitter);

    error InvalidSigner(address sender, address recoverAddr);
    error IncorrectSubmitter(address sender, address submitter);
    error RotationWindowNotPassed(uint256 current, uint256 window);
    error TaskAlreadyCompleted(uint256 taskId);
}
