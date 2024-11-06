pragma solidity ^0.8.0;

import {BaseTest, console} from "./BaseTest.sol";

import {TaskManagerUpgradeable} from "../src/TaskManagerUpgradeable.sol";
import {ITaskManager} from "../src/interfaces/ITaskManager.sol";
import {TaskSubmitter} from "../src/TaskSubmitter.sol";
import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";

contract TaskManagment is BaseTest {
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
        votingManager = VotingManagerUpgradeable(vmProxy);
        votingManager.initialize(
            tssSigner,
            address(0), // accountManager
            address(0), // assetManager
            address(0), // depositManager
            address(participantManager), // participantManager
            tmProxy, // taskManager
            address(nuvoLock) // nuvoLock
        );
    }

    function test_TaskProcess() public {
        vm.startPrank(msgSender);
        // submit task
        uint256 taskId = taskManager.nextTaskId();
        bytes memory taskContext = "--- encoded account creation task context ---";
        vm.expectEmit(true, true, true, true);
        emit ITaskManager.TaskSubmitted(taskId, taskContext, msgSender);
        taskSubmitter.submitTask(taskContext);
        assertEq(taskId, taskManager.nextTaskId() - 1);
        assertFalse(taskManager.isTaskCompleted(taskId));

        // finialize task
        bytes memory taskResult = "--- encoded task result ---";
        bytes memory callData = abi.encodeWithSelector(
            ITaskManager.markTaskCompleted.selector,
            taskId,
            taskResult
        );
        bytes memory signature = _generateSignature(tmProxy, callData, taskId, tssKey);
        vm.expectEmit(true, true, true, true);
        emit ITaskManager.TaskCompleted(taskId, msgSender, block.timestamp, taskResult);
        votingManager.verifyAndCall(tmProxy, callData, taskId, signature);
        vm.stopPrank();
    }
}
