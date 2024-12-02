// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IParticipantManager} from "./interfaces/IParticipantManager.sol";
import {ITaskManager, State} from "./interfaces/ITaskManager.sol";
import {INuvoLock} from "./interfaces/INuvoLock.sol";
import {IVotingManager, Operation} from "./interfaces/IVotingManager.sol";

contract VotingManagerUpgradeable is IVotingManager, Initializable, ReentrancyGuardUpgradeable {
    IParticipantManager public participantManager;
    ITaskManager public taskManager;
    INuvoLock public nuvoLock;

    uint256 public lastSubmissionTime;
    uint256 public constant forcedRotationWindow = 1 minutes;
    uint256 public constant taskCompletionThreshold = 1 hours;

    uint256 public tssNonce;
    address public tssSigner;
    address public nextSubmitter;

    modifier onlyCurrentSubmitter() {
        require(msg.sender == nextSubmitter, IncorrectSubmitter(msg.sender, nextSubmitter));
        _;
    }

    function initialize(
        address _tssSigner,
        address _participantManager,
        address _taskManager,
        address _nuvoLock
    ) public initializer {
        __ReentrancyGuard_init();

        participantManager = IParticipantManager(_participantManager);
        taskManager = ITaskManager(_taskManager);
        nuvoLock = INuvoLock(_nuvoLock);

        tssSigner = _tssSigner;
        lastSubmissionTime = block.timestamp;
        nextSubmitter = participantManager.getRandomParticipant(nextSubmitter);
        emit SubmitterChosen(nextSubmitter);
    }

    function setSignerAddress(
        address _newSigner,
        bytes calldata _signature
    ) external onlyCurrentSubmitter nonReentrant {
        _verifySignature(keccak256(abi.encodePacked(tssNonce++, _newSigner)), _signature);
        tssSigner = _newSigner;
        _rotateSubmitter();
    }

    function chooseNewSubmitter(bytes calldata _signature) external nonReentrant {
        require(
            participantManager.isParticipant(msg.sender),
            IParticipantManager.NotParticipant(msg.sender)
        );
        require(
            block.timestamp >= lastSubmissionTime + forcedRotationWindow,
            RotationWindowNotPassed(block.timestamp, lastSubmissionTime + forcedRotationWindow)
        );
        _verifySignature(
            keccak256(abi.encodePacked(tssNonce++, bytes("chooseNewSubmitter"))),
            _signature
        );
        // Check for uncompleted tasks and apply demerit points if needed
        ITaskManager.Task[] memory uncompletedTasks = taskManager.getUncompletedTasks();
        for (uint256 i = 0; i < uncompletedTasks.length; i++) {
            if (block.timestamp > uncompletedTasks[i].createdAt + taskCompletionThreshold) {
                //uncompleted tasks
                nuvoLock.accumulateDemeritPoints(nextSubmitter);
            }
        }
        emit SubmitterRotationRequested(msg.sender, nextSubmitter);
        _rotateSubmitter();
    }

    function verifyAndCall(
        Operation[] calldata _opts,
        bytes calldata _signature
    ) external onlyCurrentSubmitter nonReentrant {
        require(_opts.length > 0, EmptyOperationsArray());
        _verifySignature(keccak256(abi.encode(tssNonce++, _opts)), _signature);
        bool success;
        bytes memory result;
        Operation memory opt;
        for (uint8 i; i < _opts.length; ++i) {
            opt = _opts[i];
            if (opt.managerAddr == address(0)) {
                // override existing task result
                taskManager.updateTask(opt.taskId, opt.state, opt.optData);
            } else {
                (success, result) = opt.managerAddr.call(opt.optData);
                if (!success) {
                    // fail
                    taskManager.updateTask(opt.taskId, State.Failed, "");
                    emit OperationFailed(result);
                } else {
                    // success
                    taskManager.updateTask(opt.taskId, opt.state, result);
                }
            }
        }
        _rotateSubmitter();
    }

    function _rotateSubmitter() internal {
        nuvoLock.accumulateBonusPoints(msg.sender);
        lastSubmissionTime = block.timestamp;
        nextSubmitter = participantManager.getRandomParticipant(nextSubmitter);
        emit SubmitterChosen(nextSubmitter);
    }

    function _verifySignature(bytes32 _hash, bytes calldata _signature) internal view {
        bytes32 messageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash)
        );
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(_signature);
        address recoverAddr = ecrecover(messageHash, v, r, s);
        require(tssSigner == recoverAddr, InvalidSigner(msg.sender));
    }

    function _splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        require(v == 27 || v == 28, "Invalid signature version");
    }
}
