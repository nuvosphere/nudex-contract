// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IParticipantHandler} from "./interfaces/IParticipantHandler.sol";
import {ITaskManager, State} from "./interfaces/ITaskManager.sol";
import {INuvoLock} from "./interfaces/INuvoLock.sol";
import {IEntryPoint, Operation} from "./interfaces/IEntryPoint.sol";

/**
 * @dev Manage all onchain information.
 */
contract EntryPointUpgradeable is IEntryPoint, Initializable, ReentrancyGuardUpgradeable {
    IParticipantHandler public participantManager;
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

        participantManager = IParticipantHandler(_participantManager);
        taskManager = ITaskManager(_taskManager);
        nuvoLock = INuvoLock(_nuvoLock);

        tssSigner = _tssSigner;
        lastSubmissionTime = block.timestamp;
        nextSubmitter = participantManager.getRandomParticipant(block.timestamp);
        emit SubmitterChosen(nextSubmitter);
    }

    /**
     * @dev Set new tssSigner address.
     * @param _newSigner The new tssSigner address.
     * @param _signature The signature for verification.
     */
    function setSignerAddress(
        address _newSigner,
        bytes calldata _signature
    ) external onlyCurrentSubmitter nonReentrant {
        require(_newSigner != address(0), InvalidAddress());
        _verifySignature(keccak256(abi.encodePacked(tssNonce++, _newSigner)), _signature);
        tssSigner = _newSigner;
        _rotateSubmitter();
    }

    /**
     * @dev Pick new random submitter if the current submitter is inactive for too long.
     * @param _signature The signature for verification.
     */
    function chooseNewSubmitter(bytes calldata _signature) external nonReentrant {
        require(
            participantManager.isParticipant(msg.sender),
            IParticipantHandler.NotParticipant(msg.sender)
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

    /**
     * @dev Entry point for all task handlers
     * @param _opts The batch operation to be executed.
     * @param _signature The signature for verification.
     */
    function verifyAndCall(
        Operation[] calldata _opts,
        bytes calldata _signature
    ) external onlyCurrentSubmitter nonReentrant {
        _verifyOperation(_opts, _signature, tssNonce++);
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
                    // for recording revert message
                    emit OperationFailed(result);
                } else {
                    // success
                    taskManager.updateTask(opt.taskId, opt.state, result);
                }
            }
        }
        _rotateSubmitter();
    }

    /**
     * @dev Verify operation signature.
     * @param _opts The batch operation to be executed.
     * @param _signature The signature for verification.
     * @param _nonce The nonce of tssSigner.
     */
    function verifyOperation(
        Operation[] calldata _opts,
        bytes calldata _signature,
        uint256 _nonce
    ) external view {
        _verifyOperation(_opts, _signature, _nonce);
    }

    /**
     * @dev Message hash helper function.
     * @param _opts The batch operation to be executed.
     * @param _nonce The nonce of tssSigner.
     */
    function operationHash(
        Operation[] calldata _opts,
        uint256 _nonce
    ) external pure returns (bytes32 hash, bytes32 messageHash) {
        hash = keccak256(abi.encode(_nonce, _opts));
        messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Verify the validity of the operation.
     * @param _opts The batch operation to be executed.
     * @param _signature The signature for verification.
     */
    function _verifyOperation(
        Operation[] calldata _opts,
        bytes calldata _signature,
        uint256 nonce
    ) internal view {
        require(_opts.length > 0, EmptyOperationsArray());
        _verifySignature(keccak256(abi.encode(nonce, _opts)), _signature);
    }

    /**
     * @dev Verify the hash message.
     * @param _hash The hashed message.
     * @param _signature The signature for verification.
     */
    function _verifySignature(bytes32 _hash, bytes calldata _signature) internal view {
        bytes32 messageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash)
        );
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(_signature);
        address recoverAddr = ecrecover(messageHash, v, r, s);
        require(tssSigner == recoverAddr, InvalidSigner(msg.sender));
    }

    /**
     * @dev Pick a new random submiter from the participant list.
     */
    function _rotateSubmitter() internal {
        nuvoLock.accumulateBonusPoints(msg.sender);
        lastSubmissionTime = block.timestamp;
        nextSubmitter = participantManager.getRandomParticipant(block.timestamp);
        emit SubmitterChosen(nextSubmitter);
    }

    /**
     * @dev Get rsv from signature.
     */
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
