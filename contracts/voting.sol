// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./ParticipantManager.sol";

contract VotingManager is OwnableUpgradeable {
    ParticipantManager public participantManager;
    uint256 public lastSubmitterIndex;
    uint256 public lastSubmissionTime;
    uint256 public constant forcedRotationWindow = 1 minutes;

    event SubmitterChosen(address indexed newSubmitter);
    event DepositInfoSubmitted(address indexed targetAddress, uint256 amount, bytes txInfo, uint256 chainId);

    modifier onlyParticipant() {
        require(participantManager.isParticipant(msg.sender), "Not a participant");
        _;
    }

    modifier onlyCurrentSubmitter() {
        address[] memory participants = participantManager.getParticipants();
        require(participants[lastSubmitterIndex] == msg.sender, "Not the current submitter");
        _;
    }

    function initialize(address _participantManager) initializer public {
        __Ownable_init();
        participantManager = ParticipantManager(_participantManager);
    }

    function addParticipant(address newParticipant, bytes memory params, bytes memory signature) external onlyCurrentSubmitter {
        require(verifySignature(params, signature), "Invalid signature");

        participantManager.addParticipant(newParticipant);
        rotateSubmitter();
    }

    function removeParticipant(address participant, bytes memory params, bytes memory signature) external onlyCurrentSubmitter {
        require(verifySignature(params, signature), "Invalid signature");

        participantManager.removeParticipant(participant);
        rotateSubmitter();
    }

    function chooseNewSubmitter(bytes memory params, bytes memory signature) external onlyParticipant {
        require(verifySignature(params, signature), "Invalid signature");
        require(block.timestamp >= lastSubmissionTime + forcedRotationWindow, "Submitter rotation not allowed yet");

        rotateSubmitter();
    }

    function submitDepositInfo(address targetAddress, uint256 amount, bytes memory txInfo, uint256 chainId, bytes memory params, bytes memory signature) external onlyCurrentSubmitter {
        require(verifySignature(params, signature), "Invalid signature");

        emit DepositInfoSubmitted(targetAddress, amount, txInfo, chainId);
        lastSubmissionTime = block.timestamp;

        rotateSubmitter();
    }

    function rotateSubmitter() internal {
        address[] memory participants = participantManager.getParticipants();
        require(participants.length > 0, "No participants available");

        // Generate a pseudo-random number based on the block hash and block timestamp
        uint256 randomIndex = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp))) % participants.length;

        lastSubmitterIndex = randomIndex;
        emit SubmitterChosen(participants[lastSubmitterIndex]);
    }

    function verifySignature(bytes memory params, bytes memory signature) internal view returns (bool) {
        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", uint256ToString(params.length), params));
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

    function getCurrentSubmitter() external view returns (address) {
        address[] memory participants = participantManager.getParticipants();
        return participants[lastSubmitterIndex];
    }
}
