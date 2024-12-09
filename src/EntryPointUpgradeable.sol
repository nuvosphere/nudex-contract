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
    IParticipantHandler public participantHandler;
    ITaskManager public taskManager;
    INuvoLock public nuvoLock;

    uint256 public lastSubmissionTime;
    uint256 public constant FORCE_ROTATION_WINDOW = 1 minutes;
    uint256 public constant MAX_OPT_COUNT = 1 hours;

    uint256 public tssNonce;
    address public tssSigner;
    address public nextSubmitter;

    modifier onlyCurrentSubmitter() {
        require(msg.sender == nextSubmitter, IncorrectSubmitter(msg.sender, nextSubmitter));
        _;
    }

    /**
     * @dev Initializes the contract.
     * @param _tssSigner The address of tssSigner.
     * @param _participantHandler The address of ParticipantHandler contract address.
     * @param _taskManager The address of TaskManag contract address.
     * @param _nuvoLock The address of NuvoLock contract address.
     */
    function initialize(
        address _tssSigner,
        address _participantHandler,
        address _taskManager,
        address _nuvoLock
    ) public initializer {
        __ReentrancyGuard_init();

        participantHandler = IParticipantHandler(_participantHandler);
        taskManager = ITaskManager(_taskManager);
        nuvoLock = INuvoLock(_nuvoLock);

        require(_tssSigner != address(0), InvalidAddress());
        tssSigner = _tssSigner;
        lastSubmissionTime = block.timestamp;
        nextSubmitter = participantHandler.getRandomParticipant(nextSubmitter);
        emit SubmitterChosen(nextSubmitter);
    }

    /**
     * @dev Verify operation signature.
     * @param _opts The batch operation to be executed.
     * @param _nonce The nonce of tssSigner.
     * @param _signature The signature for verification.
     */
    function verifyOperation(
        Operation[] calldata _opts,
        uint256 _nonce,
        bytes calldata _signature
    ) external view returns (bool) {
        return _verifyOperation(_opts, _nonce, _signature);
    }

    /**
     * @dev Message hash helper function.
     * @param _opts The batch operation to be executed.
     * @param _nonce The nonce of tssSigner.
     */
    function operationHash(
        Operation[] calldata _opts,
        uint256 _nonce
    ) external view returns (bytes32 hash, bytes32 messageHash) {
        hash = keccak256(abi.encode(_nonce, block.chainid, _opts));
        messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
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
        require(
            _verifySignature(
                keccak256(abi.encodePacked(tssNonce++, block.chainid, _newSigner)),
                _signature
            ),
            InvalidSigner(msg.sender)
        );

        tssSigner = _newSigner;
        _rotateSubmitter();
    }

    /**
     * @dev Pick new random submitter if the current submitter is inactive for too long.
     * @param _signature The signature for verification.
     */
    function chooseNewSubmitter(
        uint256 _uncompletedTaskCount,
        bytes calldata _signature
    ) external nonReentrant {
        require(
            participantHandler.isParticipant(msg.sender),
            IParticipantHandler.NotParticipant(msg.sender)
        );
        require(
            block.timestamp >= lastSubmissionTime + FORCE_ROTATION_WINDOW,
            RotationWindowNotPassed(block.timestamp, lastSubmissionTime + FORCE_ROTATION_WINDOW)
        );
        require(
            _verifySignature(
                keccak256(abi.encodePacked(tssNonce++, block.chainid, _uncompletedTaskCount)),
                _signature
            ),
            InvalidSigner(msg.sender)
        );
        nuvoLock.accumulateDemeritPoints(nextSubmitter, _uncompletedTaskCount);
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
        require(_verifyOperation(_opts, tssNonce++, _signature), InvalidSigner(msg.sender));
        bool success;
        bytes memory result;
        Operation memory opt;
        for (uint8 i; i < _opts.length; ++i) {
            opt = _opts[i];
            if (opt.handlerAddr == address(0)) {
                // override existing task result
                taskManager.updateTask(opt.taskId, opt.state, opt.optData);
            } else {
                (success, result) = opt.handlerAddr.call(opt.optData);
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
     * @dev Verify the validity of the operation.
     * @param _opts The batch operation to be executed.
     * @param _nonce The nonce of tssSigner.
     * @param _signature The signature for verification.
     */
    function _verifyOperation(
        Operation[] calldata _opts,
        uint256 _nonce,
        bytes calldata _signature
    ) internal view returns (bool) {
        require(_opts.length > 0, EmptyOperationsArray());
        require(_opts.length <= MAX_OPT_COUNT, ExceedMaxOptCount());
        return _verifySignature(keccak256(abi.encode(_nonce, block.chainid, _opts)), _signature);
    }

    /**
     * @dev Verify the hash message.
     * @param _hash The hashed message.
     * @param _signature The signature for verification.
     */
    function _verifySignature(
        bytes32 _hash,
        bytes calldata _signature
    ) internal view returns (bool) {
        bytes32 messageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash)
        );
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(_signature);
        address recoverAddr = ecrecover(messageHash, v, r, s);
        return tssSigner == recoverAddr;
    }

    /**
     * @dev Pick a new random submiter from the participant list.
     */
    function _rotateSubmitter() internal {
        nuvoLock.accumulateBonusPoints(msg.sender, 1);
        lastSubmissionTime = block.timestamp;
        nextSubmitter = participantHandler.getRandomParticipant(nextSubmitter);
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
