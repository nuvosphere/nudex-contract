// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockParticipantManager {
    // mapping(address => bool) private participants;
    address[] public participants;
    mapping(address => bool) public isParticipant;

    function getParticipants() external view returns (address[] memory) {
        return participants;
    }

    function setParticipant(uint _index, address _addr) external {
        participants[_index] = _addr;
    }

    function addParticipant(address newParticipant) external {
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

    // Optionally: Function to simulate participant checks for more advanced tests
    function simulateCheck(address participant, bool expected) external view {
        require(isParticipant[participant] == expected, "Participant status mismatch");
    }
}
