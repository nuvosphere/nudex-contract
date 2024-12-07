pragma solidity ^0.8.0;

import "./BaseTest.sol";

import {ITaskManager} from "../src/interfaces/ITaskManager.sol";

contract TaskManagerTest is BaseTest {
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

    function test_TaskProcess() public {
        vm.startPrank(msgSender);
        // submit task
        uint64 taskId = taskManager.nextTaskId();
        bytes memory taskContext = _generateTaskContext();
        vm.expectEmit(true, true, true, true);
        emit ITaskManager.TaskSubmitted(taskId, taskContext, msgSender);
        taskSubmitter.submitTask(taskContext);
        assertEq(taskId, taskManager.nextTaskId() - 1);
        assertEq(uint8(taskManager.getTaskState(taskId)), uint8(State.Created));

        // finialize task
        bytes memory taskResult = "--- encoded task result ---";
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(address(0), State.Completed, taskId, taskResult);
        bytes memory signature = _generateOptSignature(opts, tssKey);
        vm.expectEmit(true, true, true, true);
        emit ITaskManager.TaskUpdated(
            taskId,
            msgSender,
            block.timestamp,
            State.Completed,
            taskResult
        );
        entryPoint.verifyAndCall(opts, signature);
        vm.stopPrank();
    }
}
