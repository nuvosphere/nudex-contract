// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IParticipantHandler} from "../interfaces/IParticipantHandler.sol";
import {INuvoLock} from "../interfaces/INuvoLock.sol";

contract ParticipantHandlerUpgradeable is IParticipantHandler, OwnableUpgradeable {
    INuvoLock public nuvoLock;

    address[] public participants;
    mapping(address => bool) public isParticipant;

    // _owner: EntryPoint
    function initialize(
        address _nuvoLock,
        address _owner,
        address[] calldata _initialParticipants
    ) public initializer {
        __Ownable_init(_owner);
        nuvoLock = INuvoLock(_nuvoLock);

        require(_initialParticipants.length > 2, NotEnoughParticipant());
        participants = _initialParticipants;
        for (uint256 i; i < _initialParticipants.length; ++i) {
            isParticipant[_initialParticipants[i]] = true;
        }
    }

    /**
     * @dev Add new participant.
     * @param _newParticipant The new participant to be added.
     */
    function addParticipant(address _newParticipant) external onlyOwner returns (bytes memory) {
        require(!isParticipant[_newParticipant], AlreadyParticipant(_newParticipant));
        require(nuvoLock.lockedBalanceOf(_newParticipant) > 0, NotEligible(_newParticipant));

        isParticipant[_newParticipant] = true;
        participants.push(_newParticipant);

        emit ParticipantAdded(_newParticipant);
        return abi.encodePacked(uint8(1), _newParticipant);
    }

    /**
     * @dev Remove participant.
     * @param _participant The participant to be removed.
     */
    function removeParticipant(address _participant) external onlyOwner returns (bytes memory) {
        require(participants.length > 3, NotEnoughParticipant());
        require(isParticipant[_participant], NotParticipant(_participant));

        isParticipant[_participant] = false;
        for (uint8 i; i < participants.length; i++) {
            if (participants[i] == _participant) {
                participants[i] = participants[participants.length - 1];
                participants.pop();
                break;
            }
        }

        emit ParticipantRemoved(_participant);
        return abi.encodePacked(uint8(1), _participant);
    }

    /**
     * @dev Reset the whole participants.
     * @param _newParticipants The new participant list.
     */
    function resetParticipants(
        address[] calldata _newParticipants
    ) external onlyOwner returns (bytes memory) {
        require(_newParticipants.length > 2, NotEnoughParticipant());
        // remove old participants
        for (uint8 i; i < participants.length; i++) {
            isParticipant[participants[i]] = false;
        }
        // add new participants
        for (uint8 i; i < _newParticipants.length; ++i) {
            require(isParticipant[_newParticipants[i]], NotParticipant(_newParticipants[i]));
            isParticipant[_newParticipants[i]] = true;
        }
        participants = _newParticipants;

        emit ParticipantsReset(_newParticipants);
        return abi.encodePacked(uint8(1), _newParticipants);
    }

    /**
     * @dev Get all participant.
     */
    function getParticipants() external view returns (address[] memory) {
        return participants;
    }

    /**
     * @dev Pick one random participant.
     * @param _salt Salt for randomness.
     */
    function getRandomParticipant(uint256 _salt) external view returns (address randParticipant) {
        uint256 randomIndex = uint256(
            keccak256(
                abi.encodePacked(
                    block.prevrandao, // instead of difficulty in PoS
                    block.timestamp,
                    blockhash(block.number),
                    _salt
                )
            )
        ) % participants.length;
        randParticipant = participants[randomIndex];
    }
}
