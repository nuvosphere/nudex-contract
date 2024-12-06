// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {EntryPointUpgradeable} from "../src/EntryPointUpgradeable.sol";
import {Operation} from "../src/interfaces/IVotingManager.sol";

contract SignatureGenerator is Script {
    using MessageHashUtils for bytes32;
    using ECDSA for bytes32;

    EntryPointUpgradeable votingManager;

    function setUp() public {
        votingManager = EntryPointUpgradeable(vm.envAddress("VOTING_MANAGER_ADDR"));
    }

    // forge script --rpc-url localhost script/SignatureGenerator.sol --sig "run((address,uint8, uint64, bytes)[],uint256)"
    function run(Operation[] calldata opts, uint256 _privKey) public view returns (bytes memory) {
        bytes memory encodedData = abi.encode(votingManager.tssNonce(), opts);
        bytes32 digest = keccak256(encodedData).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privKey, digest);
        console.logBytes(abi.encodePacked(r, s, v));
        return abi.encodePacked(r, s, v);
    }

    function run2(bytes32 _digest, uint256 _privKey) public view {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privKey, _digest);
        console.logBytes(abi.encodePacked(r, s, v));
    }

    // forge script script/SignatureGenerator.sol --sig "recover(bytes32,bytes)"
    function recover(bytes32 digest, bytes calldata signature) public pure returns (address) {
        return digest.recover(signature);
    }
}
