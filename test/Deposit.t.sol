pragma solidity ^0.8.0;

import {BaseTest} from "./BaseTest.sol";

import {DepositManagerUpgradeable} from "../src/DepositManagerUpgradeable.sol";
import {IDepositManager} from "../src/interfaces/IDepositManager.sol";
import {NIP20Upgradeable} from "../src/NIP20Upgradeable.sol";
import {NuDexOperationsUpgradeable} from "../src/NuDexOperationsUpgradeable.sol";
import {INuDexOperations} from "../src/interfaces/INuDexOperations.sol";
import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";

import {MockParticipantManager} from "../src/mocks/MockParticipantManager.sol";
import {MockNuvoLockUpgradeable} from "../src/mocks/MockNuvoLockUpgradeable.sol";

contract Deposit is BaseTest {
    address public user;

    DepositManagerUpgradeable public depositManager;
    NIP20Upgradeable public nip20;
    NuDexOperationsUpgradeable public nuDexOperations;
    MockParticipantManager public participantManager;
    MockNuvoLockUpgradeable public nuvoLock;

    function setUp() public override {
        super.setUp();
        user = makeAddr("user");

        // deploy mock contract
        participantManager = new MockParticipantManager(msgSender);
        nuvoLock = new MockNuvoLockUpgradeable();

        // deploy nuDexOperations
        address operationProxy = deployProxy(
            address(new NuDexOperationsUpgradeable()),
            daoContract
        );
        nuDexOperations = NuDexOperationsUpgradeable(operationProxy);
        nuDexOperations.initialize(address(participantManager), vmProxy);
        assertEq(nuDexOperations.owner(), vmProxy);

        // deploy depositManager and NIP20 contract
        address dmProxy = deployProxy(address(new DepositManagerUpgradeable()), daoContract);
        address nip20Proxy = deployProxy(address(new NIP20Upgradeable()), daoContract);
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
            operationProxy, // nudeOperation
            address(nuvoLock) // nuvoLock
        );
    }

    function test_Deposit() public {
        vm.startPrank(msgSender);
        // first deposit
        // submit task
        uint256 taskId = nuDexOperations.nextTaskId();
        bytes memory taskContext = "--- encoded deposit task context ---";
        vm.expectEmit(true, true, true, true);
        emit INuDexOperations.TaskSubmitted(taskId, taskContext, msgSender);
        nuDexOperations.submitTask(taskContext);
        assertEq(taskId, nuDexOperations.nextTaskId() - 1);

        // --- tss verify deposit ---

        // setup deposit info
        uint256 depositIndex = depositManager.getDeposits(user).length;
        assertEq(depositIndex, 0);
        uint256 depositAmount = 1 ether;
        uint256 chainId = 0;
        bytes memory txInfo = "--- encoded tx info ---";
        bytes memory extraInfo = "--- extra info ---";
        bytes memory encodedParams = abi.encodePacked(
            user,
            depositAmount,
            chainId,
            txInfo,
            extraInfo
        );
        bytes memory signature = generateSignature(encodedParams, tssKey);
        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IDepositManager.DepositRecorded(user, depositAmount, chainId, txInfo, extraInfo);
        votingManager.submitDepositInfo(user, depositAmount, chainId, txInfo, extraInfo, signature);
        IDepositManager.DepositInfo memory depositInfo = depositManager.getDeposit(
            user,
            depositIndex
        );
        assertEq(
            encodedParams,
            abi.encodePacked(
                depositInfo.targetAddress,
                depositInfo.amount,
                depositInfo.chainId,
                depositInfo.txInfo,
                depositInfo.extraInfo
            )
        );

        // second deposit
        // submit task
        taskId = nuDexOperations.nextTaskId();
        taskContext = "--- encoded deposit task context 2 ---";
        vm.expectEmit(true, true, true, true);
        emit INuDexOperations.TaskSubmitted(taskId, taskContext, msgSender);
        nuDexOperations.submitTask(taskContext);
        assertEq(taskId, nuDexOperations.nextTaskId() - 1);

        // --- tss verify deposit ---

        // setup deposit info
        depositIndex = depositManager.getDeposits(user).length;
        assertEq(depositIndex, 1); // should have increased by 1
        depositAmount = 5 ether;
        chainId = 10;
        txInfo = "--- encoded tx info 2 ---";
        extraInfo = "--- extra info 2 ---";
        encodedParams = abi.encodePacked(user, depositAmount, chainId, txInfo, extraInfo);
        signature = generateSignature(encodedParams, tssKey);

        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IDepositManager.DepositRecorded(user, depositAmount, chainId, txInfo, extraInfo);
        votingManager.submitDepositInfo(user, depositAmount, chainId, txInfo, extraInfo, signature);
        depositInfo = depositManager.getDeposit(user, depositIndex);
        assertEq(
            encodedParams,
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

        // --- tss verify deposit ---

        // setup deposit info
        uint256 depositAmount = 0; // invalid amount
        uint256 chainId = 0;
        bytes memory txInfo = "--- encoded tx info ---";
        bytes memory extraInfo = "--- extra info ---";
        bytes memory encodedParams = abi.encodePacked(
            user,
            depositAmount,
            chainId,
            txInfo,
            extraInfo
        );
        bytes memory signature = generateSignature(encodedParams, tssKey);
        // fail case: invalid amount
        vm.expectRevert(IDepositManager.InvalidAmount.selector);
        votingManager.submitDepositInfo(user, depositAmount, chainId, txInfo, extraInfo, signature);
        vm.stopPrank();
    }

    function testFuzz_DepositFuzz(address _user, uint256 _amount, bytes memory _txInfo) public {
        vm.assume(_amount > 0);
        // setup deposit info
        uint256 depositIndex = depositManager.getDeposits(user).length;
        uint256 chainId = 0;
        bytes memory extraInfo = "--- extra info ---";
        bytes memory encodedParams = abi.encodePacked(_user, _amount, chainId, _txInfo, extraInfo);
        bytes memory signature = generateSignature(encodedParams, tssKey);

        // check event and result
        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true);
        emit IDepositManager.DepositRecorded(_user, _amount, chainId, _txInfo, extraInfo);
        votingManager.submitDepositInfo(_user, _amount, chainId, _txInfo, extraInfo, signature);
        IDepositManager.DepositInfo memory depositInfo = depositManager.getDeposit(
            _user,
            depositIndex
        );
        assertEq(
            encodedParams,
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
        // --- user burn the inscription ---
        // submit task
        uint256 taskId = nuDexOperations.nextTaskId();
        bytes memory taskContext = "--- encoded withdraw task context ---";
        vm.expectEmit(true, true, true, true);
        emit INuDexOperations.TaskSubmitted(taskId, taskContext, msgSender);
        nuDexOperations.submitTask(taskContext);
        assertEq(taskId, nuDexOperations.nextTaskId() - 1);

        // --- tss verify withdrawal ---

        // setup withdrawal info
        uint256 withdrawIndex = depositManager.getWithdrawals(user).length;
        assertEq(withdrawIndex, 0);
        uint256 withdrawAmount = 1 ether;
        uint256 chainId = 0;
        bytes memory txInfo = "--- encoded tx info ---";
        bytes memory extraInfo = "--- extra info ---";
        bytes memory encodedParams = abi.encodePacked(
            user,
            withdrawAmount,
            chainId,
            txInfo,
            extraInfo
        );
        bytes memory signature = generateSignature(encodedParams, tssKey);
        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IDepositManager.WithdrawalRecorded(user, withdrawAmount, chainId, txInfo, extraInfo);
        votingManager.submitWithdrawalInfo(
            user,
            withdrawAmount,
            chainId,
            txInfo,
            extraInfo,
            signature
        );
        IDepositManager.WithdrawalInfo memory withdrawInfo = depositManager.getWithdrawal(
            user,
            withdrawIndex
        );
        assertEq(
            encodedParams,
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

    function test_withdrawRevert() public {
        vm.startPrank(msgSender);
        // --- submit task ---

        // --- tss verify withdraw ---

        // setup withdraw info
        uint256 withdrawAmount = 0; // invalid amount
        uint256 chainId = 0;
        bytes memory txInfo = "--- encoded tx info ---";
        bytes memory extraInfo = "--- extra info ---";
        bytes memory encodedParams = abi.encodePacked(
            user,
            withdrawAmount,
            chainId,
            txInfo,
            extraInfo
        );
        bytes memory signature = generateSignature(encodedParams, tssKey);
        // fail case: invalid amount
        vm.expectRevert(IDepositManager.InvalidAmount.selector);
        votingManager.submitWithdrawalInfo(
            user,
            withdrawAmount,
            chainId,
            txInfo,
            extraInfo,
            signature
        );
        vm.stopPrank();
    }
}
