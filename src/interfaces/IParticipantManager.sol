// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IParticipantManager {
    event ParticipantAdded(address indexed participant);
    event ParticipantRemoved(address indexed participant);

    error AlreadyParticipant();
    error NotEligible();
    error NotParticipant();
    error NotEnoughParticipant();

    function isParticipant(address) external view returns (bool);

    function addParticipant(address newParticipant) external;

    function removeParticipant(address participant) external;

    function getParticipants() external view returns (address[] memory);

    function getRandomParticipant(address _salt) external view returns (address randParticipant);
}
