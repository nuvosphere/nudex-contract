// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

    address public tssSigner;
    address public nextSubmitter;

    event SubmitterChosen(address indexed newSubmitter);
    event SubmitterRotationRequested(address indexed requester, address indexed currentSubmitter);
    event RewardPerPeriodVoted(uint256 newRewardPerPeriod);

    error InvalidSigner();
    error IncorrectSubmitter();
    error RotationWindowNotPassed();
    error TaskAlreadyCompleted();

    modifier onlyParticipant() {
        require(participantManager.isParticipant(msg.sender), IParticipantManager.NotParticipant());
        _;
    }

    modifier onlyCurrentSubmitter() {
        require(msg.sender == nextSubmitter, IncorrectSubmitter());
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

    function chooseNewSubmitter(bytes calldata _signature) external onlyParticipant nonReentrant {
        require(
            block.timestamp >= lastSubmissionTime + forcedRotationWindow,
            RotationWindowNotPassed()
        );
        require(_verifySignature(bytes("chooseNewSubmitter"), _signature), InvalidSigner());
        // Check for uncompleted tasks and apply demerit points if needed
        INuDexOperations.Task[] memory uncompletedTasks = nuDexOperations.getUncompletedTasks();
        for (uint256 i = 0; i < uncompletedTasks.length; i++) {
            if (block.timestamp > uncompletedTasks[i].createdAt + taskCompletionThreshold) {
                //uncompleted tasks
                nuvoLock.accumulateDemeritPoints(nextSubmitter);
            }
        }
        emit SubmitterRotationRequested(msg.sender, nextSubmitter);
        rotateSubmitter();
    }

    function addParticipant(
        address newParticipant,
        bytes calldata signature
    ) external onlyCurrentSubmitter nonReentrant {
        require(_verifySignature(abi.encodePacked(newParticipant), signature), InvalidSigner());
        participantManager.addParticipant(newParticipant);
        rotateSubmitter();
    }

    function removeParticipant(
        address participant,
        bytes calldata signature
    ) external onlyCurrentSubmitter nonReentrant {
        require(_verifySignature(abi.encodePacked(participant), signature), InvalidSigner());
        participantManager.removeParticipant(participant);
        rotateSubmitter();
    }

    function submitTaskReceipt(
        uint256 taskId,
        bytes memory result,
        bytes calldata signature
    ) external onlyCurrentSubmitter nonReentrant {
        require(!nuDexOperations.isTaskCompleted(taskId), TaskAlreadyCompleted());
        bytes memory encodedParams = abi.encodePacked(taskId, result);
        require(_verifySignature(encodedParams, signature), InvalidSigner());
        nuDexOperations.markTaskCompleted(taskId, result);
        rotateSubmitter();
    }

    function preconfirmTask(
        uint256 _taskId,
        bytes calldata _result,
        bytes calldata _signature
    ) external onlyCurrentSubmitter nonReentrant {
        require(!nuDexOperations.isTaskCompleted(_taskId), TaskAlreadyCompleted());
        bytes memory encodedParams = abi.encodePacked(_taskId, _result);
        require(_verifySignature(encodedParams, _signature), InvalidSigner());
        nuDexOperations.preconfirmTask(_taskId, _result);
        rotateSubmitter();
    }

    function confirmTasks(bytes calldata _signature) external onlyCurrentSubmitter nonReentrant {
        require(_verifySignature(bytes("confirmTasks"), _signature), InvalidSigner());
        nuDexOperations.confirmAllTasks();
        rotateSubmitter();
    }

    function registerAccount(
        address _user,
        uint _account,
        IAccountManager.Chain _chain,
        uint _index,
        address _address,
        bytes calldata _signature
    ) external onlyCurrentSubmitter nonReentrant {
        bytes memory encodedParams = abi.encodePacked(_user, _account, _chain, _index, _address);
        require(_verifySignature(encodedParams, _signature), InvalidSigner());
        accountManager.registerNewAddress(_user, _account, _chain, _index, _address);
        rotateSubmitter();
    }

    function submitDepositInfo(
        address targetAddress,
        uint256 amount,
        uint256 chainId,
        bytes memory txInfo,
        bytes memory extraInfo,
        bytes calldata signature
    ) external onlyCurrentSubmitter nonReentrant {
        bytes memory encodedParams = abi.encodePacked(
            targetAddress,
            amount,
            chainId,
            txInfo,
            extraInfo
        );
        require(_verifySignature(encodedParams, signature), InvalidSigner());
        depositManager.recordDeposit(targetAddress, amount, chainId, txInfo, extraInfo);
        rotateSubmitter();
    }

    function submitWithdrawalInfo(
        address targetAddress,
        uint256 amount,
        uint256 chainId,
        bytes memory txInfo,
        bytes memory extraInfo,
        bytes calldata signature
    ) external onlyCurrentSubmitter nonReentrant {
        bytes memory encodedParams = abi.encodePacked(
            targetAddress,
            amount,
            chainId,
            txInfo,
            extraInfo
        );
        require(_verifySignature(encodedParams, signature), InvalidSigner());
        depositManager.recordWithdrawal(targetAddress, amount, chainId, txInfo, extraInfo);
        rotateSubmitter();
    }

    function setRewardPerPeriod(
        uint256 newRewardPerPeriod,
        bytes calldata signature
    ) external onlyCurrentSubmitter nonReentrant {
        bytes memory encodedParams = abi.encodePacked(newRewardPerPeriod);
        require(_verifySignature(encodedParams, signature), InvalidSigner());

        nuvoLock.setRewardPerPeriod(newRewardPerPeriod);
        emit RewardPerPeriodVoted(newRewardPerPeriod);
        rotateSubmitter();
    }

    function addBonusPoints(
        address[] calldata _voters,
        bytes calldata _signature
    ) external onlyCurrentSubmitter nonReentrant {
        bytes memory encodedParams = abi.encodePacked(_voters);
        require(_verifySignature(encodedParams, _signature), InvalidSigner());
        require(_voters.length < type(uint16).max, "overflow");
        for (uint16 i; i < _voters.length; ++i) {
            nuvoLock.accumulateBonusPoints(_voters[i]);
        }
        rotateSubmitter();
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
        require(_verifySignature(encodedParams, signature), InvalidSigner());
        assetManager.listAsset(name, nuDexName, assetType, contractAddress, chainId);

        rotateSubmitter();
    }

    function delistAsset(
        IAssetManager.AssetType assetType,
        address contractAddress,
        uint256 chainId,
        bytes calldata signature
    ) external onlyCurrentSubmitter nonReentrant {
        bytes memory encodedParams = abi.encodePacked(assetType, contractAddress, chainId);
        require(_verifySignature(encodedParams, signature), InvalidSigner());
        assetManager.delistAsset(assetType, contractAddress, chainId);

        rotateSubmitter();
    }

    function rotateSubmitter() internal {
        nuvoLock.accumulateBonusPoints(msg.sender);
        lastSubmissionTime = block.timestamp;
        nextSubmitter = participantManager.getRandomParticipant(nextSubmitter);
        emit SubmitterChosen(nextSubmitter);
    }

    function _verifySignature(
        bytes memory encodedParams,
        bytes calldata signature
    ) internal view returns (bool) {
        bytes32 hash = keccak256(
            abi.encodePacked(_uint256ToString(encodedParams.length), encodedParams)
        );
        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(signature);
        return tssSigner == ecrecover(messageHash, v, r, s);
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
