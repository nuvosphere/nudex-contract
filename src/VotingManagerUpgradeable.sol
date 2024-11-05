// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IAccountManager} from "./interfaces/IAccountManager.sol";
import {IAssetManager} from "./interfaces/IAssetManager.sol";
import {IDepositManager} from "./interfaces/IDepositManager.sol";
import {IParticipantManager} from "./interfaces/IParticipantManager.sol";
import {INuDexOperations} from "./interfaces/INuDexOperations.sol";
import {INuvoLock} from "./interfaces/INuvoLock.sol";
import {console} from "forge-std/console.sol";

contract VotingManagerUpgradeable is Initializable, ReentrancyGuardUpgradeable {
    IAccountManager public accountManager;
    IAssetManager public assetManager;
    IDepositManager public depositManager;
    IParticipantManager public participantManager;
    INuDexOperations public nuDexOperations;
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
        address _accountManager,
        address _assetManager,
        address _depositManager,
        address _participantManager,
        address _nuDexOperations,
        address _nuvoLock
    ) public initializer {
        __ReentrancyGuard_init();

        accountManager = IAccountManager(_accountManager);
        assetManager = IAssetManager(_assetManager);
        depositManager = IDepositManager(_depositManager);
        participantManager = IParticipantManager(_participantManager);
        nuDexOperations = INuDexOperations(_nuDexOperations);
        nuvoLock = INuvoLock(_nuvoLock);

        tssSigner = _tssSigner;
        lastSubmissionTime = block.timestamp;
        nextSubmitter = participantManager.getRandomParticipant(nextSubmitter);
    }

    function setSignerAddress(
        address _newSigner,
        bytes calldata _signature
    ) external onlyCurrentSubmitter nonReentrant {
        _verifySignature(abi.encodePacked(_newSigner), _signature);
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
        _verifySignature(bytes("chooseNewSubmitter"), _signature);
        // Check for uncompleted tasks and apply demerit points if needed
        INuDexOperations.Task[] memory uncompletedTasks = nuDexOperations.getUncompletedTasks();
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
        bytes memory _result,
        bytes calldata _signature
    ) external onlyCurrentSubmitter nonReentrant {
        require(!nuDexOperations.isTaskCompleted(_taskId), TaskAlreadyCompleted(_taskId));
        bytes memory encodedParams = abi.encodePacked(_taskId, _result);
        _verifySignature(encodedParams, _signature);
        nuDexOperations.markTaskCompleted(_taskId, _result);
        _rotateSubmitter();
    }

    function preconfirmTask(
        uint256 _taskId,
        bytes calldata _result,
        bytes calldata _signature
    ) external onlyCurrentSubmitter nonReentrant {
        require(!nuDexOperations.isTaskCompleted(_taskId), TaskAlreadyCompleted(_taskId));
        bytes memory encodedParams = abi.encodePacked(_taskId, _result);
        _verifySignature(encodedParams, _signature);
        nuDexOperations.preconfirmTask(_taskId, _result);
        _rotateSubmitter();
    }

    function confirmTasks(bytes calldata _signature) external onlyCurrentSubmitter nonReentrant {
        _verifySignature(bytes("confirmTasks"), _signature);
        nuDexOperations.confirmAllTasks();
        _rotateSubmitter();
    }

    function listAsset(
        string memory name,
        string memory nuDexName,
        IAssetManager.AssetType assetType,
        address contractAddress,
        uint256 chainId,
        bytes calldata signature
    ) external onlyCurrentSubmitter nonReentrant {
        bytes memory encodedParams = abi.encodePacked(
            name,
            nuDexName,
            assetType,
            contractAddress,
            chainId
        );
        _verifySignature(encodedParams, signature);
        assetManager.listAsset(name, nuDexName, assetType, contractAddress, chainId);

        _rotateSubmitter();
    }

    function delistAsset(
        IAssetManager.AssetType assetType,
        address contractAddress,
        uint256 chainId,
        bytes calldata signature
    ) external onlyCurrentSubmitter nonReentrant {
        bytes memory encodedParams = abi.encodePacked(assetType, contractAddress, chainId);
        _verifySignature(encodedParams, signature);
        assetManager.delistAsset(assetType, contractAddress, chainId);

        _rotateSubmitter();
    }

    function verifyAndCall(
        address _target,
        bytes calldata _data,
        bytes calldata _signature
    ) external onlyCurrentSubmitter nonReentrant {
        _verifySignature(_data, _signature);
        (bool success, bytes memory data) = _target.call(_data);
        if (!success) {
            assembly {
                let revertStringLength := mload(data)
                let revertStringPtr := add(data, 0x20)
                revert(revertStringPtr, revertStringLength)
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

    function _verifySignature(bytes memory encodedParams, bytes calldata signature) internal {
        bytes32 hash = keccak256(
            abi.encodePacked(tssNonce++, _uint256ToString(encodedParams.length), encodedParams)
        );
        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(signature);
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

    function _uint256ToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
