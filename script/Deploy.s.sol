// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";

contract Deploy is Script {
    VotingManagerUpgradeable public votingManager;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        votingManager = new VotingManagerUpgradeable();

        vm.stopBroadcast();
    }
}
