pragma solidity ^0.8.0;

import "./BaseTest.sol";

import {ITaskManager} from "../src/interfaces/ITaskManager.sol";

contract EntryPointTest is BaseTest {
    address public tmProxy;

    function setUp() public override {
        super.setUp();

        // initialize votingManager link to all contracts
        votingManager = EntryPointUpgradeable(vmProxy);
        votingManager.initialize(
            tssSigner, // tssSigner
            address(participantManager), // participantManager
            address(taskManager), // taskManager
            address(nuvoLock) // nuvoLock
        );
    }

    function test_ChooseNewSubmitter() public {
        vm.startPrank(msgSender);
        // submit task
        bytes memory taskContext = "--- task context ---";
        skip(1 minutes);
        // finialize task
        bytes memory encodedData = abi.encodePacked(
            votingManager.tssNonce(),
            bytes("chooseNewSubmitter")
        );
        bytes memory signature = _generateSignature(encodedData, tssKey);
        vm.expectEmit(true, true, true, true);
        emit IEntryPoint.SubmitterRotationRequested(msgSender, msgSender);
        votingManager.chooseNewSubmitter(signature);
        vm.stopPrank();
    }
}
