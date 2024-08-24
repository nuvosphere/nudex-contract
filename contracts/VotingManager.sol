// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./ParticipantManager.sol";
import "./NuvoLockUpgradeable.sol";
import "./DepositManager.sol";
import "./AssetManager.sol";

contract VotingManager is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    ParticipantManager public participantManager;
    NuvoLockUpgradeable public nuvoLock;
    DepositManager public depositManager;

    uint256 public lastSubmitterIndex;
    uint256 public lastSubmissionTime;
    uint256 public constant forcedRotationWindow = 1 minutes;

    event SubmitterChosen(address indexed newSubmitter);
    event DepositInfoSubmitted(address indexed targetAddress, uint256 amount, bytes txInfo, uint256 chainId, bytes extraInfo);
    event RewardPerPeriodVoted(uint256 newRewardPerPeriod);
    event ParticipantAdded(address indexed newParticipant);
    event ParticipantRemoved(address indexed participant);
    event SubmitterRotationRequested(address indexed requester, address indexed currentSubmitter);
    event AssetListed(bytes32 indexed assetId);
    event AssetDelisted(bytes32 indexed assetId);
    event TaskCompleted(uint256 indexed taskId, address indexed submitter, uint256 completedAt, bytes taskResult);

    modifier onlyParticipant() {
        require(participantManager.isParticipant(msg.sender), "Not a participant");
        _;
    }

    modifier onlyCurrentSubmitter() {
        address[] memory participants = participantManager.getParticipants();
        require(participants[lastSubmitterIndex] == msg.sender, "Not the current submitter");
        _;
    }

    function initialize(address _participantManager, address _nuvoLock, address _depositManager, address _initialOwner) initializer public {
        __Ownable_init(_initialOwner);
        __ReentrancyGuard_init();
        participantManager = ParticipantManager(_participantManager);
        nuvoLock = NuvoLockUpgradeable(_nuvoLock);
        depositManager = DepositManager(_depositManager);
    }

    function addParticipant(address newParticipant, bytes memory params, bytes memory signature) external onlyCurrentSubmitter nonReentrant {
        require(verifySignature(abi.encodePacked(newParticipant), signature), "Invalid signature");

        participantManager.addParticipant(newParticipant);
        nuvoLock.accumulateBonusPoints(msg.sender);
        rotateSubmitter();

        emit ParticipantAdded(newParticipant);
    }

    function removeParticipant(address participant, bytes memory params, bytes memory signature) external onlyCurrentSubmitter nonReentrant {
        require(verifySignature(abi.encodePacked(participant), signature), "Invalid signature");

        participantManager.removeParticipant(participant);
        nuvoLock.accumulateBonusPoints(msg.sender);
        rotateSubmitter();

        emit ParticipantRemoved(participant);
    }

    function chooseNewSubmitter(address currentSubmitter, bytes memory params, bytes memory signature) external onlyParticipant nonReentrant {
        require(verifySignature(abi.encodePacked(currentSubmitter), signature), "Invalid signature");
        require(currentSubmitter == getCurrentSubmitter(), "Incorrect current submitter");
        require(block.timestamp >= lastSubmissionTime + forcedRotationWindow, "Submitter rotation not allowed yet");

        rotateSubmitter();

        emit SubmitterRotationRequested(msg.sender, currentSubmitter);
    }

    function submitDepositInfo(
        address targetAddress,
        uint256 amount,
        bytes memory txInfo,
        uint256 chainId,
        bytes memory extraInfo,  // Added extraInfo parameter
        bytes memory signature
    ) external onlyCurrentSubmitter nonReentrant {
        bytes memory encodedParams = abi.encodePacked(targetAddress, amount, txInfo, chainId, extraInfo);
        require(verifySignature(encodedParams, signature), "Invalid signature");

        depositManager.recordDeposit(targetAddress, amount, txInfo, chainId);
        lastSubmissionTime = block.timestamp;

        nuvoLock.accumulateBonusPoints(msg.sender);
        rotateSubmitter();

        emit DepositInfoSubmitted(targetAddress, amount, txInfo, chainId, extraInfo);  // Updated event
    }

    function setRewardPerPeriod(uint256 newRewardPerPeriod, bytes memory signature) external onlyCurrentSubmitter nonReentrant {
        bytes memory encodedParams = abi.encodePacked(newRewardPerPeriod);
        require(verifySignature(encodedParams, signature), "Invalid signature");

        nuvoLock.setRewardPerPeriod(newRewardPerPeriod);
        emit RewardPerPeriodVoted(newRewardPerPeriod);

        nuvoLock.accumulateBonusPoints(msg.sender);
        rotateSubmitter();
    }

    function listAsset(
        string memory name,
        string memory nuDexName,
        AssetManager.AssetType assetType,
        address contractAddress,
        uint256 chainId,
        bytes memory signature
    ) external onlyCurrentSubmitter nonReentrant {
        bytes memory encodedParams = abi.encodePacked(name, nuDexName, assetType, contractAddress, chainId);
        require(verifySignature(encodedParams, signature), "Invalid signature");

        assetManager.listAsset(name, nuDexName, assetType, contractAddress, chainId);
        bytes32 assetId = assetManager.getAssetIdentifier(assetType, contractAddress, chainId);

        nuvoLock.accumulateBonusPoints(msg.sender);
        rotateSubmitter();

        emit AssetListed(assetId);
    }

    function delistAsset(
        AssetManager.AssetType assetType,
        address contractAddress,
        uint256 chainId,
        bytes memory signature
    ) external onlyCurrentSubmitter nonReentrant {
        bytes memory encodedParams = abi.encodePacked(assetType, contractAddress, chainId);
        require(verifySignature(encodedParams, signature), "Invalid signature");

        assetManager.delistAsset(assetType, contractAddress, chainId);
        bytes32 assetId = assetManager.getAssetIdentifier(assetType, contractAddress, chainId);

        nuvoLock.accumulateBonusPoints(msg.sender);
        rotateSubmitter();

        emit AssetDelisted(assetId);
    }

    function submitTaskReceipt(uint256 taskId, bytes memory result, bytes memory signature) external onlyCurrentSubmitter nonReentrant {
        
        require(!nuDexOperations.tasks(taskId).isCompleted, "Task already completed");
        bytes memory encodedParams = abi.encodePacked(taskId, result);
        require(verifySignature(encodedParams, signature), "Invalid signature");

        nuDexOperations.markTaskCompleted(taskId);

        emit TaskCompleted(taskId, msg.sender, block.timestamp, result);

        // Rotate the submitter
        rotateSubmitter();
    }

    function rotateSubmitter() internal {
        address[] memory participants = participantManager.getParticipants();
        require(participants.length > 0, "No participants available");

        uint256 randomIndex = uint256(keccak256(abi.encodePacked(
            block.prevrandao, // instead of difficulty in PoS
            block.timestamp,
            blockhash(block.number - 1),
            lastSubmitterIndex
        ))) % participants.length;

        lastSubmitterIndex = randomIndex;
        emit SubmitterChosen(participants[lastSubmitterIndex]);
    }

    function verifySignature(bytes memory encodedParams, bytes memory signature) internal view returns (bool) {
        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", uint256ToString(encodedParams.length), encodedParams));
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        address signer = ecrecover(messageHash, v, r, s);

        return participantManager.isParticipant(signer);
    }

    function splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
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

    function uint256ToString(uint256 value) internal pure returns (string memory) {
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

    function getCurrentSubmitter() public view returns (address) {
        address[] memory participants = participantManager.getParticipants();
        return participants[lastSubmitterIndex];
    }
}
