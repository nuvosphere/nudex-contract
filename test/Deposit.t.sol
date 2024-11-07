pragma solidity ^0.8.0;

import {BaseTest, console} from "./BaseTest.sol";

import {DepositManagerUpgradeable} from "../src/DepositManagerUpgradeable.sol";
import {IDepositManager} from "../src/interfaces/IDepositManager.sol";
import {NIP20Upgradeable} from "../src/NIP20Upgradeable.sol";
import {TaskManagerUpgradeable} from "../src/TaskManagerUpgradeable.sol";
import {ITaskManager} from "../src/interfaces/ITaskManager.sol";
import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";

contract Deposit is BaseTest {
    address public user;

    DepositManagerUpgradeable public depositManager;
    NIP20Upgradeable public nip20;

    address public dmProxy;

    bytes public constant TASK_CONTEXT = "--- encoded deposit task context ---";

    function setUp() public override {
        super.setUp();
        user = makeAddr("user");

        // deploy depositManager and NIP20 contract
        dmProxy = _deployProxy(address(new DepositManagerUpgradeable()), daoContract);
        address nip20Proxy = _deployProxy(address(new NIP20Upgradeable()), daoContract);
        nip20 = NIP20Upgradeable(nip20Proxy);
        nip20.initialize(dmProxy);
        assertEq(nip20.owner(), dmProxy);
        depositManager = DepositManagerUpgradeable(dmProxy);
        depositManager.initialize(vmProxy, nip20Proxy);
        assertEq(depositManager.owner(), vmProxy);

        // initialize votingManager link to all contracts
        votingManager = VotingManagerUpgradeable(vmProxy);
        votingManager.initialize(
            tssSigner,
            address(0), // accountManager
            address(0), // assetManager
            dmProxy, // depositManager
            address(participantManager), // participantManager
            address(taskManager), // taskManager
            address(nuvoLock) // nuvoLock
        );
    }

    function test_Deposit() public {
        vm.startPrank(msgSender);
        // setup deposit info
        uint256 taskId = taskSubmitter.submitTask(TASK_CONTEXT);
        uint256 depositIndex = depositManager.getDeposits(user).length;
        assertEq(depositIndex, 0);
        uint256 depositAmount = 1 ether;
        uint64 chainId = 0;
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
        bytes memory signature = _generateSignature(dmProxy, callData, taskId, tssKey);
        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IDepositManager.DepositRecorded(user, depositAmount, chainId, txInfo, extraInfo);
        votingManager.verifyAndCall(dmProxy, callData, taskId, signature);

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
        signature = _generateSignature(dmProxy, callData, taskId, tssKey);

        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IDepositManager.DepositRecorded(user, depositAmount, chainId, txInfo, extraInfo);
        votingManager.verifyAndCall(dmProxy, callData, taskId, signature);
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
        uint256 taskId = taskSubmitter.submitTask(TASK_CONTEXT);

        // --- tss verify deposit ---

        // setup deposit info
        uint256 depositAmount = 0; // invalid amount
        uint64 chainId = 0;
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
        bytes memory signature = _generateSignature(dmProxy, callData, taskId, tssKey);
        // fail case: invalid amount
        vm.expectRevert(IDepositManager.InvalidAmount.selector);
        votingManager.verifyAndCall(dmProxy, callData, taskId, signature);
        vm.stopPrank();
    }

    function test_DepositBatch() public {
        vm.startPrank(msgSender);
        uint16 batchSize = 20;

        // setup deposit info
        uint256[] memory taskIds = new uint256[](batchSize);
        address[] memory users = new address[](batchSize);
        uint256[] memory amounts = new uint256[](batchSize);
        uint64[] memory chainIds = new uint64[](batchSize);
        bytes[] memory txInfos = new bytes[](batchSize);
        bytes[] memory extraInfos = new bytes[](batchSize);
        for (uint16 i; i < batchSize; ++i) {
            taskIds[i] = taskSubmitter.submitTask(TASK_CONTEXT);
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            amounts[i] = 1 ether;
            chainIds[i] = 0;
            txInfos[i] = "--- encoded tx info ---";
            extraInfos[i] = "--- extra info ---";
        }
        bytes memory callData = abi.encodeWithSelector(
            IDepositManager.recordDeposit_Batch.selector,
            users,
            amounts,
            chainIds,
            txInfos,
            extraInfos
        );
        bytes memory encodedData = abi.encodePacked(
            votingManager.tssNonce(),
            dmProxy,
            callData,
            taskIds
        );
        bytes memory signature = _generateSignature(encodedData, tssKey);
        for (uint16 i; i < batchSize; ++i) {
            assertFalse(taskManager.isTaskCompleted(taskIds[i]));
        }
        votingManager.verifyAndCall_Batch(dmProxy, callData, taskIds, signature);
        IDepositManager.DepositInfo memory depositInfo;
        for (uint16 i; i < batchSize; ++i) {
            assertTrue(taskManager.isTaskCompleted(taskIds[i]));
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

        // fail: different input parameters length
        users = new address[](batchSize + 1);
        users[users.length - 1] = msgSender;
        callData = abi.encodeWithSelector(
            IDepositManager.recordDeposit_Batch.selector,
            users,
            amounts,
            chainIds,
            txInfos,
            extraInfos
        );
        encodedData = abi.encodePacked(votingManager.tssNonce(), dmProxy, callData, taskIds);
        signature = _generateSignature(encodedData, tssKey);
        vm.expectRevert(IDepositManager.InvalidInput.selector);
        votingManager.verifyAndCall_Batch(dmProxy, callData, taskIds, signature);

        vm.stopPrank();
    }

    function testFuzz_DepositFuzz(address _user, uint256 _amount, bytes memory _txInfo) public {
        vm.assume(_amount > 0);
        // setup deposit info
        uint256 taskId = taskSubmitter.submitTask(TASK_CONTEXT);
        uint256 depositIndex = depositManager.getDeposits(user).length;
        uint64 chainId = 0;
        bytes memory extraInfo = "--- extra info ---";
        bytes memory callData = abi.encodeWithSelector(
            IDepositManager.recordDeposit.selector,
            _user,
            _amount,
            chainId,
            _txInfo,
            extraInfo
        );
        bytes memory signature = _generateSignature(dmProxy, callData, taskId, tssKey);

        // check event and result
        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true);
        emit IDepositManager.DepositRecorded(_user, _amount, chainId, _txInfo, extraInfo);
        votingManager.verifyAndCall(dmProxy, callData, taskId, signature);
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
        // first withdrawal
        // setup withdrawal info
        uint256 taskId = taskSubmitter.submitTask(TASK_CONTEXT);
        uint256 withdrawIndex = depositManager.getWithdrawals(user).length;
        assertEq(withdrawIndex, 0);
        uint256 withdrawAmount = 1 ether;
        uint64 chainId = 0;
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
        bytes memory signature = _generateSignature(dmProxy, callData, taskId, tssKey);
        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IDepositManager.WithdrawalRecorded(user, withdrawAmount, chainId, txInfo, extraInfo);
        votingManager.verifyAndCall(dmProxy, callData, taskId, signature);
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
        uint256 taskId = taskSubmitter.submitTask(TASK_CONTEXT);

        // --- tss verify withdraw ---

        // setup withdraw info
        uint256 withdrawAmount = 0; // invalid amount
        uint64 chainId = 0;
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
        bytes memory signature = _generateSignature(dmProxy, callData, taskId, tssKey);
        // fail case: invalid amount
        vm.expectRevert(IDepositManager.InvalidAmount.selector);
        votingManager.verifyAndCall(dmProxy, callData, taskId, signature);
        vm.stopPrank();
    }

    function test_WithdrawBatch() public {
        vm.startPrank(msgSender);
        uint16 batchSize = 20;

        // setup deposit info
        uint256[] memory taskIds = new uint256[](batchSize);
        address[] memory users = new address[](batchSize);
        uint256[] memory amounts = new uint256[](batchSize);
        uint64[] memory chainIds = new uint64[](batchSize);
        bytes[] memory txInfos = new bytes[](batchSize);
        bytes[] memory extraInfos = new bytes[](batchSize);
        for (uint16 i; i < batchSize; ++i) {
            taskIds[i] = taskSubmitter.submitTask(TASK_CONTEXT);
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            amounts[i] = 1 ether;
            chainIds[i] = 0;
            txInfos[i] = "--- encoded tx info ---";
            extraInfos[i] = "--- extra info ---";
        }
        bytes memory callData = abi.encodeWithSelector(
            IDepositManager.recordWithdrawal_Batch.selector,
            users,
            amounts,
            chainIds,
            txInfos,
            extraInfos
        );
        bytes memory encodedData = abi.encodePacked(
            votingManager.tssNonce(),
            dmProxy,
            callData,
            taskIds
        );
        bytes memory signature = _generateSignature(encodedData, tssKey);
        for (uint16 i; i < batchSize; ++i) {
            assertFalse(taskManager.isTaskCompleted(taskIds[i]));
        }
        votingManager.verifyAndCall_Batch(dmProxy, callData, taskIds, signature);
        IDepositManager.WithdrawalInfo memory withdrawalInfo;
        for (uint16 i; i < batchSize; ++i) {
            assertTrue(taskManager.isTaskCompleted(taskIds[i]));
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
        // fail: different input parameters length
        users = new address[](batchSize + 1);
        users[users.length - 1] = msgSender;
        callData = abi.encodeWithSelector(
            IDepositManager.recordWithdrawal_Batch.selector,
            users,
            amounts,
            chainIds,
            txInfos,
            extraInfos
        );
        encodedData = abi.encodePacked(votingManager.tssNonce(), dmProxy, callData, taskIds);
        signature = _generateSignature(encodedData, tssKey);
        vm.expectRevert(IDepositManager.InvalidInput.selector);
        votingManager.verifyAndCall_Batch(dmProxy, callData, taskIds, signature);

        vm.stopPrank();
    }
}
