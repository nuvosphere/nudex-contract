// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IParticipantManager {
    event ParticipantAdded(address indexed participant);
    event ParticipantRemoved(address indexed participant);

    error AlreadyParticipant(address);
    error NotEligible(address);
    error NotParticipant(address);
    error NotEnoughParticipant();

    function isParticipant(address) external view returns (bool);

    function addParticipant(address newParticipant) external returns (bytes memory);

    function removeParticipant(address participant) external returns (bytes memory);

    function getParticipants() external view returns (address[] memory);

    function getRandomParticipant(uint256 _salt) external view returns (address randParticipant);
}
