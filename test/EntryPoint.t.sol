pragma solidity ^0.8.0;

import "./BaseTest.sol";

import {ITaskManager} from "../src/interfaces/ITaskManager.sol";

contract EntryPointTest is BaseTest {
    address public tmProxy;

    function setUp() public override {
        super.setUp();

        // initialize entryPoint link to all contracts
        entryPoint = EntryPointUpgradeable(vmProxy);
        entryPoint.initialize(
            tssSigner, // tssSigner
            address(participantHandler), // participantHandler
            address(taskManager), // taskManager
            address(nuvoLock) // nuvoLock
        );
    }

    function test_ChooseNewSubmitter() public {
        vm.startPrank(msgSender);
        uint256 demeritPoint = 1;
        skip(1 minutes);
        // finialize task
        bytes memory encodedData = abi.encodePacked(
            entryPoint.tssNonce(),
            block.chainid,
            demeritPoint
        );
        bytes memory signature = _generateDataSignature(encodedData, tssKey);
        vm.expectEmit(true, true, true, true);
        emit IEntryPoint.SubmitterRotationRequested(msgSender, msgSender);
        entryPoint.chooseNewSubmitter(demeritPoint, signature);
        vm.stopPrank();
    }
}
