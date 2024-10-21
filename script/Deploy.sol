// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {VotingManager} from "../contracts/VotingManager.sol";

contract Deploy is Script {
    VotingManager public votingManager;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        votingManager = new VotingManager();

        vm.stopBroadcast();
    }
}
