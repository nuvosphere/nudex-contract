pragma solidity ^0.8.0;

import "./BaseTest.sol";

import {DepositManagerUpgradeable} from "../src/handlers/DepositManagerUpgradeable.sol";
import {IDepositManager} from "../src/interfaces/IDepositManager.sol";
import {ITaskManager} from "../src/interfaces/ITaskManager.sol";

contract Deposit is BaseTest {
    address public user;

    DepositManagerUpgradeable public depositManager;

    address public dmProxy;

    bytes public constant TASK_CONTEXT = "--- encoded deposit task context ---";

    function setUp() public override {
        super.setUp();
        user = makeAddr("user");

        // deploy depositManager and NIP20 contract
        dmProxy = _deployProxy(address(new DepositManagerUpgradeable()), daoContract);
        depositManager = DepositManagerUpgradeable(dmProxy);
        depositManager.initialize(vmProxy);
        assertEq(depositManager.owner(), vmProxy);

        // initialize votingManager link to all contracts
        votingManager = VotingManagerUpgradeable(vmProxy);
        votingManager.initialize(
            tssSigner, // tssSigner
            address(participantManager), // participantManager
            address(taskManager), // taskManager
            address(nuvoLock) // nuvoLock
        );
    }

    function test_Deposit() public {
        vm.startPrank(msgSender);
        // setup deposit info
        uint64 taskId = taskSubmitter.submitTask(TASK_CONTEXT);
        uint256 depositIndex = depositManager.getDeposits(user).length;
        assertEq(depositIndex, 0);
        uint256 depositAmount = 1 ether;
        uint256 chainId = 0;
        bytes memory txInfo = "--- encoded tx info ---";
        bytes memory extraInfo = "--- extra info ---";
        bytes memory callData = abi.encodeWithSelector(
            IDepositManager.recordDeposit.selector,
            user,
            depositAmount,
            chainId,
            txInfo,
            extraInfo
        );
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(dmProxy, State.Completed, taskId, callData);
        bytes memory signature = _generateSignature(opts, tssKey);
        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IDepositManager.DepositRecorded(user, depositAmount, chainId, txInfo, extraInfo);
        votingManager.verifyAndCall(opts, signature);

        IDepositManager.DepositInfo memory depositInfo = depositManager.getDeposit(
            user,
            depositIndex
        );
        assertEq(
            abi.encodePacked(user, depositAmount, chainId, txInfo, extraInfo),
            abi.encodePacked(
                depositInfo.targetAddress,
                depositInfo.amount,
                depositInfo.chainId,
                depositInfo.txInfo,
                depositInfo.extraInfo
            )
        );

        // second deposit
        // setup deposit info
        taskId = taskSubmitter.submitTask(TASK_CONTEXT);
        depositIndex = depositManager.getDeposits(user).length;
        assertEq(depositIndex, 1); // should have increased by 1
        depositAmount = 5 ether;
        chainId = 10;
        txInfo = "--- encoded tx info 2 ---";
        extraInfo = "--- extra info 2 ---";
        callData = abi.encodeWithSelector(
            IDepositManager.recordDeposit.selector,
            user,
            depositAmount,
            chainId,
            txInfo,
            extraInfo
        );
        opts[0] = Operation(dmProxy, State.Completed, taskId, callData);
        signature = _generateSignature(opts, tssKey);

        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IDepositManager.DepositRecorded(user, depositAmount, chainId, txInfo, extraInfo);
        votingManager.verifyAndCall(opts, signature);
        depositInfo = depositManager.getDeposit(user, depositIndex);
        assertEq(
            abi.encodePacked(user, depositAmount, chainId, txInfo, extraInfo),
            abi.encodePacked(
                depositInfo.targetAddress,
                depositInfo.amount,
                depositInfo.chainId,
                depositInfo.txInfo,
                depositInfo.extraInfo
            )
        );
        vm.stopPrank();
    }

    function test_DepositRevert() public {
        vm.startPrank(msgSender);
        // --- submit task ---
        uint64 taskId = taskSubmitter.submitTask(TASK_CONTEXT);

        // --- tss verify deposit ---

        // setup deposit info
        uint256 depositAmount = 0; // invalid amount
        uint256 chainId = 0;
        bytes memory txInfo = "--- encoded tx info ---";
        bytes memory extraInfo = "--- extra info ---";
        bytes memory callData = abi.encodeWithSelector(
            IDepositManager.recordDeposit.selector,
            user,
            depositAmount,
            chainId,
            txInfo,
            extraInfo
        );
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(dmProxy, State.Completed, taskId, callData);
        bytes memory signature = _generateSignature(opts, tssKey);
        // fail case: invalid amount
        vm.expectEmit(true, true, true, true);
        emit IVotingManager.OperationFailed(
            abi.encodeWithSelector(IDepositManager.InvalidAmount.selector)
        );
        votingManager.verifyAndCall(opts, signature);
        vm.stopPrank();
    }

    function test_DepositBatch() public {
        vm.startPrank(msgSender);
        uint8 batchSize = 20;

        // setup deposit info
        bytes memory callData;
        Operation[] memory opts = new Operation[](batchSize);
        uint64[] memory taskIds = new uint64[](batchSize);
        address[] memory users = new address[](batchSize);
        uint256[] memory amounts = new uint256[](batchSize);
        uint256[] memory chainIds = new uint256[](batchSize);
        bytes[] memory txInfos = new bytes[](batchSize);
        bytes[] memory extraInfos = new bytes[](batchSize);
        for (uint8 i; i < batchSize; ++i) {
            taskIds[i] = taskSubmitter.submitTask(abi.encodePacked(TASK_CONTEXT, i));
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            amounts[i] = 1 ether;
            chainIds[i] = 0;
            txInfos[i] = "--- encoded tx info ---";
            extraInfos[i] = "--- extra info ---";
            callData = abi.encodeWithSelector(
                IDepositManager.recordDeposit.selector,
                users[i],
                amounts[i],
                chainIds[i],
                txInfos[i],
                extraInfos[i]
            );
            opts[i] = Operation(dmProxy, State.Completed, taskIds[i], callData);
        }
        for (uint16 i; i < batchSize; ++i) {
            assertEq(uint8(taskManager.getTaskState(taskIds[i])), uint8(State.Created));
        }
        bytes memory signature = _generateSignature(opts, tssKey);
        votingManager.verifyAndCall(opts, signature);
        IDepositManager.DepositInfo memory depositInfo;
        for (uint8 i; i < batchSize; ++i) {
            assertEq(uint8(taskManager.getTaskState(taskIds[i])), uint8(State.Completed));
            depositInfo = depositManager.getDeposit(users[i], 0);
            assertEq(
                abi.encodePacked(users[i], amounts[i], chainIds[i], txInfos[i], extraInfos[i]),
                abi.encodePacked(
                    depositInfo.targetAddress,
                    depositInfo.amount,
                    depositInfo.chainId,
                    depositInfo.txInfo,
                    depositInfo.extraInfo
                )
            );
        }
        vm.stopPrank();
    }

    function testFuzz_DepositFuzz(address _user, uint256 _amount, bytes memory _txInfo) public {
        vm.assume(_amount > 0);
        // setup deposit info
        uint64 taskId = taskSubmitter.submitTask(TASK_CONTEXT);
        uint256 depositIndex = depositManager.getDeposits(user).length;
        uint256 chainId = 0;
        bytes memory extraInfo = "--- extra info ---";
        bytes memory callData = abi.encodeWithSelector(
            IDepositManager.recordDeposit.selector,
            _user,
            _amount,
            chainId,
            _txInfo,
            extraInfo
        );
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(dmProxy, State.Completed, taskId, callData);
        bytes memory signature = _generateSignature(opts, tssKey);

        // check event and result
        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true);
        emit IDepositManager.DepositRecorded(_user, _amount, chainId, _txInfo, extraInfo);
        votingManager.verifyAndCall(opts, signature);
        IDepositManager.DepositInfo memory depositInfo = depositManager.getDeposit(
            _user,
            depositIndex
        );
        assertEq(
            abi.encodePacked(_user, _amount, chainId, _txInfo, extraInfo),
            abi.encodePacked(
                depositInfo.targetAddress,
                depositInfo.amount,
                depositInfo.chainId,
                depositInfo.txInfo,
                depositInfo.extraInfo
            )
        );
    }

    function test_Withdraw() public {
        vm.startPrank(msgSender);
        // setup withdrawal info
        uint64 taskId = taskSubmitter.submitTask(TASK_CONTEXT);
        uint256 withdrawIndex = depositManager.getWithdrawals(user).length;
        assertEq(withdrawIndex, 0);
        uint256 withdrawAmount = 1 ether;
        uint256 chainId = 0;
        bytes memory txInfo = "--- encoded tx info ---";
        bytes memory extraInfo = "--- extra info ---";
        bytes memory callData = abi.encodeWithSelector(
            IDepositManager.recordWithdrawal.selector,
            user,
            withdrawAmount,
            chainId,
            txInfo,
            extraInfo
        );
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(dmProxy, State.Completed, taskId, callData);
        bytes memory signature = _generateSignature(opts, tssKey);
        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IDepositManager.WithdrawalRecorded(user, withdrawAmount, chainId, txInfo, extraInfo);
        votingManager.verifyAndCall(opts, signature);
        IDepositManager.WithdrawalInfo memory withdrawInfo = depositManager.getWithdrawal(
            user,
            withdrawIndex
        );
        assertEq(
            abi.encodePacked(user, withdrawAmount, chainId, txInfo, extraInfo),
            abi.encodePacked(
                withdrawInfo.targetAddress,
                withdrawInfo.amount,
                withdrawInfo.chainId,
                withdrawInfo.txInfo,
                withdrawInfo.extraInfo
            )
        );
        vm.stopPrank();
    }

    function test_WithdrawRevert() public {
        vm.startPrank(msgSender);
        // --- submit task ---
        uint64 taskId = taskSubmitter.submitTask(TASK_CONTEXT);

        // --- tss verify withdraw ---

        // setup withdraw info
        uint256 withdrawAmount = 0; // invalid amount
        uint256 chainId = 0;
        bytes memory txInfo = "--- encoded tx info ---";
        bytes memory extraInfo = "--- extra info ---";
        bytes memory callData = abi.encodeWithSelector(
            IDepositManager.recordWithdrawal.selector,
            user,
            withdrawAmount,
            chainId,
            txInfo,
            extraInfo
        );
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(dmProxy, State.Completed, taskId, callData);
        bytes memory signature = _generateSignature(opts, tssKey);
        // fail case: invalid amount
        vm.expectEmit(true, true, true, true);
        emit IVotingManager.OperationFailed(
            abi.encodeWithSelector(IDepositManager.InvalidAmount.selector)
        );
        votingManager.verifyAndCall(opts, signature);
        vm.stopPrank();
    }

    function test_WithdrawBatch() public {
        vm.startPrank(msgSender);
        uint8 batchSize = 20;

        // setup withdraw info
        bytes memory callData;
        Operation[] memory opts = new Operation[](batchSize);
        uint64[] memory taskIds = new uint64[](batchSize);
        address[] memory users = new address[](batchSize);
        uint256[] memory amounts = new uint256[](batchSize);
        uint256[] memory chainIds = new uint256[](batchSize);
        bytes[] memory txInfos = new bytes[](batchSize);
        bytes[] memory extraInfos = new bytes[](batchSize);
        for (uint16 i; i < batchSize; ++i) {
            taskIds[i] = taskSubmitter.submitTask(abi.encodePacked(TASK_CONTEXT, i));
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            amounts[i] = 1 ether;
            chainIds[i] = 0;
            txInfos[i] = "--- encoded tx info ---";
            extraInfos[i] = "--- extra info ---";
            callData = abi.encodeWithSelector(
                IDepositManager.recordWithdrawal.selector,
                users[i],
                amounts[i],
                chainIds[i],
                txInfos[i],
                extraInfos[i]
            );
            opts[i] = Operation(dmProxy, State.Completed, taskIds[i], callData);
        }
        bytes memory signature = _generateSignature(opts, tssKey);
        for (uint16 i; i < batchSize; ++i) {
            assertEq(uint8(taskManager.getTaskState(taskIds[i])), uint8(State.Created));
        }
        votingManager.verifyAndCall(opts, signature);
        IDepositManager.WithdrawalInfo memory withdrawalInfo;
        for (uint16 i; i < batchSize; ++i) {
            assertEq(uint8(taskManager.getTaskState(taskIds[i])), uint8(State.Completed));
            withdrawalInfo = depositManager.getWithdrawal(users[i], 0);
            assertEq(
                abi.encodePacked(users[i], amounts[i], chainIds[i], txInfos[i], extraInfos[i]),
                abi.encodePacked(
                    withdrawalInfo.targetAddress,
                    withdrawalInfo.amount,
                    withdrawalInfo.chainId,
                    withdrawalInfo.txInfo,
                    withdrawalInfo.extraInfo
                )
            );
        }

        vm.stopPrank();
    }
}
