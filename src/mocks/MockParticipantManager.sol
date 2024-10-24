// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockParticipantManager {
    address[] public participants;
    mapping(address => bool) public isParticipant;

    constructor(address _participant) {
        addParticipant(_participant);
    }

    function setParticipant(uint _index, address _addr) external {
        participants[_index] = _addr;
    }

    function addParticipant(address newParticipant) public {
        require(!isParticipant[newParticipant], "Already a participant");
        participants.push(newParticipant);
        isParticipant[newParticipant] = true;
    }

    function removeParticipant(address participant) external {
        require(isParticipant[participant], "Not a participant");
        isParticipant[participant] = false;
        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i] == participant) {
                participants[i] = participants[participants.length - 1];
                participants.pop();
                break;
            }
        }
    }

    function simulateCheck(address participant, bool expected) external view {
        require(isParticipant[participant] == expected, "Participant status mismatch");
    }

    function getParticipants() external view returns (address[] memory) {
        return participants;
    }

    function getRandomParticipant(address _salt) external view returns (address randParticipant) {
        uint256 randomIndex = uint256(
            keccak256(
                abi.encodePacked(
                    block.prevrandao, // instead of difficulty in PoS
                    block.timestamp,
                    blockhash(block.number - 1),
                    _salt
                )
            )
        ) % participants.length;
        randParticipant = participants[randomIndex];
    }
}
