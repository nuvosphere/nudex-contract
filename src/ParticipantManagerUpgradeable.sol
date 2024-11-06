// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IParticipantManager} from "./interfaces/IParticipantManager.sol";
import {INuvoLock} from "./interfaces/INuvoLock.sol";

contract ParticipantManagerUpgradeable is IParticipantManager, OwnableUpgradeable {
    INuvoLock public nuvoLock;

    address[] public participants;
    mapping(address => bool) public isParticipant;

    // _owner: votingManager
    function initialize(
        address _nuvoLock,
        address _owner,
        address[] calldata _initialParticipants
    ) public initializer {
        __Ownable_init(_owner);
        nuvoLock = INuvoLock(_nuvoLock);

        // FIXME: do we check the eligibility of these address?
        require(_initialParticipants.length > 2, NotEnoughParticipant());
        participants = _initialParticipants;
        for (uint256 i; i < _initialParticipants.length; ++i) {
            isParticipant[_initialParticipants[i]] = true;
        }
    }

    function addParticipant(address newParticipant) external onlyOwner returns (bytes memory) {
        require(!isParticipant[newParticipant], AlreadyParticipant(newParticipant));
        require(nuvoLock.lockedBalanceOf(newParticipant) > 0, NotEligible(newParticipant));

        participants.push(newParticipant);
        isParticipant[newParticipant] = true;

        emit ParticipantAdded(newParticipant);
        return abi.encodePacked(true, uint8(1), newParticipant);
    }

    function removeParticipant(address participant) external onlyOwner returns (bytes memory) {
        require(participants.length > 3, NotEnoughParticipant());
        require(isParticipant[participant], NotParticipant(participant));

        isParticipant[participant] = false;
        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i] == participant) {
                participants[i] = participants[participants.length - 1];
                participants.pop();
                break;
            }
        }

        emit ParticipantRemoved(participant);
        return abi.encodePacked(true, uint8(1), participant);
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
