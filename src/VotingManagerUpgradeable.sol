// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IParticipantManager} from "./interfaces/IParticipantManager.sol";
import {ITaskManager} from "./interfaces/ITaskManager.sol";
import {INuvoLock} from "./interfaces/INuvoLock.sol";
import {console} from "forge-std/console.sol";

contract VotingManagerUpgradeable is Initializable, ReentrancyGuardUpgradeable {
    IParticipantManager public participantManager;
    ITaskManager public taskManager;
    INuvoLock public nuvoLock;

    uint256 public lastSubmissionTime;
    uint256 public constant forcedRotationWindow = 1 minutes;
    uint256 public constant taskCompletionThreshold = 1 hours;

    uint256 public tssNonce;
    address public tssSigner;
    address public nextSubmitter;

    event SubmitterChosen(address indexed newSubmitter);
    event SubmitterRotationRequested(address indexed requester, address indexed currentSubmitter);

    error InvalidSigner(address sender, address recoverAddr);
    error IncorrectSubmitter(address sender, address submitter);
    error RotationWindowNotPassed(uint256 current, uint256 window);
    error TaskAlreadyCompleted(uint256 taskId);

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

    function submitTaskReceipt(
        uint256 _taskId,
        bytes calldata _result,
        bytes calldata _signature
    ) external onlyCurrentSubmitter nonReentrant {
        require(!taskManager.isTaskCompleted(_taskId), TaskAlreadyCompleted(_taskId));
        _verifySignature(keccak256(abi.encodePacked(tssNonce++, _taskId, _result)), _signature);
        taskManager.markTaskCompleted(_taskId, _result);
        _rotateSubmitter();
    }

    function verifyAndCall(
        address _target,
        bytes calldata _data,
        uint256 _taskId,
        bytes calldata _signature
    ) external onlyCurrentSubmitter nonReentrant {
        _verifySignature(
            keccak256(abi.encodePacked(tssNonce++, _target, _data, _taskId)),
            _signature
        );
        (bool success, bytes memory result) = _target.call(_data);
        if (!success) {
            assembly {
                let revertStringLength := mload(result)
                let revertStringPtr := add(result, 0x20)
                revert(revertStringPtr, revertStringLength)
            }
        }
        taskManager.markTaskCompleted(_taskId, result);
        _rotateSubmitter();
    }

    function verifyAndCall_Batch(
        address _target,
        bytes calldata _data,
        uint256[] calldata _taskIds,
        bytes calldata _signature
    ) external onlyCurrentSubmitter nonReentrant {
        _verifySignature(
            keccak256(abi.encodePacked(tssNonce++, _target, _data, _taskIds)),
            _signature
        );
        (bool success, bytes memory result) = _target.call(_data);
        if (!success) {
            assembly {
                let revertStringLength := mload(result)
                let revertStringPtr := add(result, 0x20)
                revert(revertStringPtr, revertStringLength)
            }
        }
        bytes[] memory results = abi.decode(result, (bytes[]));
        taskManager.markTaskCompleted_Batch(_taskIds, results);
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
        require(tssSigner == recoverAddr, InvalidSigner(msg.sender, recoverAddr));
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
