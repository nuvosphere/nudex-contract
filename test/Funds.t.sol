pragma solidity ^0.8.0;

import "./BaseTest.sol";

import {FundsHandlerUpgradeable} from "../src/handlers/FundsHandlerUpgradeable.sol";
import {IFundsHandler} from "../src/interfaces/IFundsHandler.sol";
import {ITaskManager} from "../src/interfaces/ITaskManager.sol";

contract FundsTest is BaseTest {
    address public user;

    FundsHandlerUpgradeable public fundsHandler;

    address public dmProxy;

    function setUp() public override {
        super.setUp();
        user = makeAddr("user");

        // deploy fundsHandler
        dmProxy = _deployProxy(address(new FundsHandlerUpgradeable()), daoContract);
        fundsHandler = FundsHandlerUpgradeable(dmProxy);
        fundsHandler.initialize(vmProxy);
        assertEq(fundsHandler.owner(), vmProxy);

        // initialize entryPoint link to all contracts
        entryPoint = EntryPointUpgradeable(vmProxy);
        entryPoint.initialize(
            tssSigner, // tssSigner
            address(participantHandler), // participantHandler
            address(taskManager), // taskManager
            address(nuvoLock) // nuvoLock
        );
    }

    function test_Deposit() public {
        vm.startPrank(msgSender);
        // setup deposit info
        uint64 taskId = taskSubmitter.submitTask(_generateTaskContext());
        uint256 depositIndex = fundsHandler.getDeposits(user).length;
        assertEq(depositIndex, 0);
        uint256 depositAmount = 1 ether;
        uint256 chainId = 0;
        bytes memory txInfo = "--- encoded tx info ---";
        bytes memory extraInfo = "--- extra info ---";
        bytes memory callData = abi.encodeWithSelector(
            IFundsHandler.recordDeposit.selector,
            user,
            depositAmount,
            chainId,
            txInfo,
            extraInfo
        );
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(dmProxy, State.Completed, taskId, callData);
        bytes memory signature = _generateOptSignature(opts, tssKey);
        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IFundsHandler.DepositRecorded(user, depositAmount, chainId, txInfo, extraInfo);
        entryPoint.verifyAndCall(opts, signature);

        IFundsHandler.DepositInfo memory depositInfo = fundsHandler.getDeposit(user, depositIndex);
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
        taskId = taskSubmitter.submitTask(_generateTaskContext());
        depositIndex = fundsHandler.getDeposits(user).length;
        assertEq(depositIndex, 1); // should have increased by 1
        depositAmount = 5 ether;
        chainId = 10;
        txInfo = "--- encoded tx info 2 ---";
        extraInfo = "--- extra info 2 ---";
        callData = abi.encodeWithSelector(
            IFundsHandler.recordDeposit.selector,
            user,
            depositAmount,
            chainId,
            txInfo,
            extraInfo
        );
        opts[0] = Operation(dmProxy, State.Completed, taskId, callData);
        signature = _generateOptSignature(opts, tssKey);

        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IFundsHandler.DepositRecorded(user, depositAmount, chainId, txInfo, extraInfo);
        entryPoint.verifyAndCall(opts, signature);
        depositInfo = fundsHandler.getDeposit(user, depositIndex);
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
        uint64 taskId = taskSubmitter.submitTask(_generateTaskContext());

        // --- tss verify deposit ---

        // setup deposit info
        uint256 depositAmount = 0; // invalid amount
        uint256 chainId = 0;
        bytes memory txInfo = "--- encoded tx info ---";
        bytes memory extraInfo = "--- extra info ---";
        bytes memory callData = abi.encodeWithSelector(
            IFundsHandler.recordDeposit.selector,
            user,
            depositAmount,
            chainId,
            txInfo,
            extraInfo
        );
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(dmProxy, State.Completed, taskId, callData);
        bytes memory signature = _generateOptSignature(opts, tssKey);
        // fail case: invalid amount
        vm.expectEmit(true, true, true, true);
        emit IEntryPoint.OperationFailed(
            abi.encodeWithSelector(IFundsHandler.InvalidAmount.selector)
        );
        entryPoint.verifyAndCall(opts, signature);
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
            taskIds[i] = taskSubmitter.submitTask(_generateTaskContext());
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            amounts[i] = 1 ether;
            chainIds[i] = 0;
            txInfos[i] = "--- encoded tx info ---";
            extraInfos[i] = "--- extra info ---";
            callData = abi.encodeWithSelector(
                IFundsHandler.recordDeposit.selector,
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
        bytes memory signature = _generateOptSignature(opts, tssKey);
        entryPoint.verifyAndCall(opts, signature);
        IFundsHandler.DepositInfo memory depositInfo;
        for (uint8 i; i < batchSize; ++i) {
            assertEq(uint8(taskManager.getTaskState(taskIds[i])), uint8(State.Completed));
            depositInfo = fundsHandler.getDeposit(users[i], 0);
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
        vm.startPrank(msgSender);
        vm.assume(_amount > 0);
        // setup deposit info
        uint64 taskId = taskSubmitter.submitTask(_generateTaskContext());
        uint256 depositIndex = fundsHandler.getDeposits(user).length;
        uint256 chainId = 0;
        bytes memory extraInfo = "--- extra info ---";
        bytes memory callData = abi.encodeWithSelector(
            IFundsHandler.recordDeposit.selector,
            _user,
            _amount,
            chainId,
            _txInfo,
            extraInfo
        );
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(dmProxy, State.Completed, taskId, callData);
        bytes memory signature = _generateOptSignature(opts, tssKey);

        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IFundsHandler.DepositRecorded(_user, _amount, chainId, _txInfo, extraInfo);
        entryPoint.verifyAndCall(opts, signature);
        IFundsHandler.DepositInfo memory depositInfo = fundsHandler.getDeposit(_user, depositIndex);
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
        vm.stopPrank();
    }

    function test_Withdraw() public {
        vm.startPrank(msgSender);
        // setup withdrawal info
        uint64 taskId = taskSubmitter.submitTask(_generateTaskContext());
        uint256 withdrawIndex = fundsHandler.getWithdrawals(user).length;
        assertEq(withdrawIndex, 0);
        uint256 withdrawAmount = 1 ether;
        uint256 chainId = 0;
        bytes memory txInfo = "--- encoded tx info ---";
        bytes memory extraInfo = "--- extra info ---";
        bytes memory callData = abi.encodeWithSelector(
            IFundsHandler.recordWithdrawal.selector,
            user,
            withdrawAmount,
            chainId,
            txInfo,
            extraInfo
        );
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(dmProxy, State.Completed, taskId, callData);
        bytes memory signature = _generateOptSignature(opts, tssKey);
        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IFundsHandler.WithdrawalRecorded(user, withdrawAmount, chainId, txInfo, extraInfo);
        entryPoint.verifyAndCall(opts, signature);
        IFundsHandler.WithdrawalInfo memory withdrawInfo = fundsHandler.getWithdrawal(
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
        uint64 taskId = taskSubmitter.submitTask(_generateTaskContext());

        // --- tss verify withdraw ---

        // setup withdraw info
        uint256 withdrawAmount = 0; // invalid amount
        uint256 chainId = 0;
        bytes memory txInfo = "--- encoded tx info ---";
        bytes memory extraInfo = "--- extra info ---";
        bytes memory callData = abi.encodeWithSelector(
            IFundsHandler.recordWithdrawal.selector,
            user,
            withdrawAmount,
            chainId,
            txInfo,
            extraInfo
        );
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(dmProxy, State.Completed, taskId, callData);
        bytes memory signature = _generateOptSignature(opts, tssKey);
        // fail case: invalid amount
        vm.expectEmit(true, true, true, true);
        emit IEntryPoint.OperationFailed(
            abi.encodeWithSelector(IFundsHandler.InvalidAmount.selector)
        );
        entryPoint.verifyAndCall(opts, signature);
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
            taskIds[i] = taskSubmitter.submitTask(_generateTaskContext());
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            amounts[i] = 1 ether;
            chainIds[i] = 0;
            txInfos[i] = "--- encoded tx info ---";
            extraInfos[i] = "--- extra info ---";
            callData = abi.encodeWithSelector(
                IFundsHandler.recordWithdrawal.selector,
                users[i],
                amounts[i],
                chainIds[i],
                txInfos[i],
                extraInfos[i]
            );
            opts[i] = Operation(dmProxy, State.Completed, taskIds[i], callData);
        }
        bytes memory signature = _generateOptSignature(opts, tssKey);
        for (uint16 i; i < batchSize; ++i) {
            assertEq(uint8(taskManager.getTaskState(taskIds[i])), uint8(State.Created));
        }
        entryPoint.verifyAndCall(opts, signature);
        IFundsHandler.WithdrawalInfo memory withdrawalInfo;
        for (uint16 i; i < batchSize; ++i) {
            assertEq(uint8(taskManager.getTaskState(taskIds[i])), uint8(State.Completed));
            withdrawalInfo = fundsHandler.getWithdrawal(users[i], 0);
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
