// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";

contract SignatureGenerator is Script {
    using MessageHashUtils for bytes32;

    VotingManagerUpgradeable votingManager;

    function setUp() public {
        votingManager = VotingManagerUpgradeable(vm.envAddress("VOTING_MANAGER_ADDR"));
    }

    function run(
        address _target,
        bytes memory _callData,
        uint256 _taskId,
        uint256 _privKey
    ) public view {
        bytes memory encodedData = abi.encodePacked(
            votingManager.tssNonce(),
            _target,
            _callData,
            _taskId
        );
        bytes32 digest = keccak256(encodedData).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privKey, digest);
        console.logBytes(abi.encodePacked(r, s, v));
    }
}
