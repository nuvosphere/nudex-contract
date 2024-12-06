pragma solidity ^0.8.0;

import "./BaseTest.sol";

import {ITaskManager} from "../src/interfaces/ITaskManager.sol";

contract TaskManagerTest is BaseTest {
    address public tmProxy;

    function setUp() public override {
        super.setUp();

        // deploy taskManager
        tmProxy = _deployProxy(address(new TaskManagerUpgradeable()), daoContract);
        taskSubmitter = new TaskSubmitter(tmProxy);
        taskManager = TaskManagerUpgradeable(tmProxy);
        taskManager.initialize(address(taskSubmitter), vmProxy);
        assertEq(taskManager.owner(), vmProxy);

        // initialize votingManager link to all contracts
        votingManager = EntryPointUpgradeable(vmProxy);
        votingManager.initialize(
            tssSigner, // tssSigner
            address(participantManager), // participantManager
            tmProxy, // taskManager
            address(nuvoLock) // nuvoLock
        );
    }

    function test_TaskProcess() public {
        vm.startPrank(msgSender);
        // submit task
        uint64 taskId = taskManager.nextTaskId();
        bytes memory taskContext = "--- encoded account creation task context ---";
        vm.expectEmit(true, true, true, true);
        emit ITaskManager.TaskSubmitted(taskId, taskContext, msgSender);
        taskSubmitter.submitTask(taskContext);
        assertEq(taskId, taskManager.nextTaskId() - 1);
        assertEq(uint8(taskManager.getTaskState(taskId)), uint8(State.Created));

        // finialize task
        bytes memory taskResult = "--- encoded task result ---";
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(address(0), State.Completed, taskId, taskResult);
        bytes memory signature = _generateSignature(opts, tssKey);
        vm.expectEmit(true, true, true, true);
        emit ITaskManager.TaskUpdated(
            taskId,
            msgSender,
            block.timestamp,
            State.Completed,
            taskResult
        );
        votingManager.verifyAndCall(opts, signature);
        vm.stopPrank();
    }
}
