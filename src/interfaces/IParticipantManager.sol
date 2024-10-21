// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IParticipantManager {

    event ParticipantAdded(address indexed participant);
    event ParticipantRemoved(address indexed participant);

    function isParticipant(address) external view returns (bool);

    function addParticipant(address newParticipant) external;

    function removeParticipant(address participant) external;

    function isEligible(address participant) external view returns (bool);

    function getParticipants() external view returns (address[] memory);
}
