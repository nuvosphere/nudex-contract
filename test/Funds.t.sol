pragma solidity ^0.8.0;

import "./BaseTest.sol";
import {TestHelper} from "./utils/TestHelper.sol";

import {AccountHandlerUpgradeable, AddressCategory} from "../src/handlers/AccountHandlerUpgradeable.sol";
import {AssetHandlerUpgradeable} from "../src/handlers/AssetHandlerUpgradeable.sol";
import {AssetType, AssetParam, TokenInfo} from "../src/interfaces/IAssetHandler.sol";
import {FundsHandlerUpgradeable} from "../src/handlers/FundsHandlerUpgradeable.sol";
import {IFundsHandler, DepositParam, WithdrawalParam, ConsolidateTaskParam, TransferParam} from "../src/interfaces/IFundsHandler.sol";
import {ITaskManager, State} from "../src/interfaces/ITaskManager.sol";

contract FundsTest is BaseTest {
    bytes32 public constant FUNDS_ROLE = keccak256("FUNDS_ROLE");

    uint64 public constant CHAIN_ID = 1;
    uint32 public constant DEFAULT_ACCOUNT = 10001;
    string public constant DEPOSIT_ADDRESS = "0xDepositAddress";
    bytes32 public constant TICKER = "TOKEN_TICKER_18";
    uint256 public constant MIN_DEPOSIT_AMOUNT = 0.1 ether;
    uint256 public constant MIN_WITHDRAW_AMOUNT = 0.1 ether;
    uint256 public constant DEFAULT_AMOUNT = 1 ether;
    uint256 public constant WITHDRAW_FEE = 0.3 ether;

    FundsHandlerUpgradeable public fundsHandler;

    DepositParam[] public depositTaskParams;
    WithdrawalParam[] public withdrawTaskParams;

    uint64[] private taskIds;
    State[] private taskStates;

    function setUp() public override {
        super.setUp();

        // setup accountHandler
        address accountHandlerProxy = _deployProxy(
            address(new AccountHandlerUpgradeable(address(taskManager))),
            daoContract
        );
        AccountHandlerUpgradeable accountHandler = AccountHandlerUpgradeable(accountHandlerProxy);
        accountHandler.initialize(thisAddr, thisAddr, msgSender);
        accountHandler.registerNewAddress(
            msgSender,
            DEFAULT_ACCOUNT,
            AddressCategory.EVM,
            0,
            DEPOSIT_ADDRESS
        );

        // setup assetHandler
        address ahProxy = _deployProxy(
            address(new AssetHandlerUpgradeable(address(taskManager))),
            daoContract
        );
        AssetHandlerUpgradeable assetHandler = AssetHandlerUpgradeable(ahProxy);
        assetHandler.initialize(thisAddr, thisAddr, msgSender);
        AssetParam memory assetParam = AssetParam(
            18,
            true,
            true,
            MIN_DEPOSIT_AMOUNT,
            MIN_WITHDRAW_AMOUNT,
            ""
        );
        assetHandler.listNewAsset(TICKER, assetParam);
        TokenInfo[] memory testTokenInfo = new TokenInfo[](1);
        testTokenInfo[0] = TokenInfo(
            CHAIN_ID,
            AssetType.ERC20,
            true,
            uint8(6),
            "0xContractAddress",
            "SYMBOL",
            WITHDRAW_FEE
        );
        assetHandler.linkToken(TICKER, testTokenInfo);
        // deploy fundsHandler
        address fundsHandlerProxy = _deployProxy(
            address(
                new FundsHandlerUpgradeable(accountHandlerProxy, ahProxy, address(taskManager))
            ),
            daoContract
        );
        fundsHandler = FundsHandlerUpgradeable(fundsHandlerProxy);
        fundsHandler.initialize(daoContract, entryPointProxy, msgSender);
        assertTrue(fundsHandler.hasRole(ENTRYPOINT_ROLE, entryPointProxy));

        // assign handlers
        assetHandler.grantRole(FUNDS_ROLE, fundsHandlerProxy);
        handlers.push(fundsHandlerProxy);
        taskManager.initialize(daoContract, entryPointProxy, handlers);

        // default task param
        depositTaskParams.push(
            DepositParam(
                DEFAULT_ACCOUNT,
                CHAIN_ID,
                AddressCategory.EVM,
                TICKER,
                DEFAULT_AMOUNT,
                "txHash",
                100,
                0
            )
        );
        withdrawTaskParams.push(
            WithdrawalParam(
                DEFAULT_ACCOUNT,
                CHAIN_ID,
                AddressCategory.EVM,
                TICKER,
                DEPOSIT_ADDRESS,
                DEFAULT_AMOUNT,
                bytes32(uint256(0))
            )
        );
        taskIds.push(1);
        taskStates.push(State.Completed);
    }

    function test_Deposit() public {
        vm.startPrank(msgSender);
        // setup deposit info
        assertEq(fundsHandler.totalValueLocked(TICKER), 0);
        uint256 depositIndex = fundsHandler.getDeposits(DEFAULT_ACCOUNT, TICKER, CHAIN_ID).length;
        fundsHandler.submitDepositTask(depositTaskParams);
        taskOpts[0].initialCalldata = abi.encodeWithSelector(
            fundsHandler.recordDeposit.selector,
            depositTaskParams[0]
        );
        signature = _generateOptSignature(taskOpts, tssKey);
        // check event and result
        vm.expectEmit(true, true, true, true);
        emit ITaskManager.TaskUpdated(taskIds, taskStates);
        entryPoint.verifyAndCall(taskOpts, signature);

        uint256 depositAmount = fundsHandler.getDeposit(
            DEFAULT_ACCOUNT,
            TICKER,
            CHAIN_ID,
            depositIndex
        );
        assertEq(depositAmount, depositTaskParams[0].amount);
        assertEq(fundsHandler.totalValueLocked(TICKER), depositAmount);
        depositIndex = fundsHandler.getDeposits(DEFAULT_ACCOUNT, TICKER, CHAIN_ID).length;
        assertEq(depositIndex, 1); // should have increased by 1

        // second deposit
        // setup deposit info
        uint64 newChainId = uint64(1);
        uint256 newAmount = 5 ether;
        depositTaskParams[0].chainId = newChainId;
        depositTaskParams[0].amount = newAmount;
        fundsHandler.submitDepositTask(depositTaskParams);
        taskIds[0] = 2;
        taskOpts[0].taskId++;
        taskOpts[0].initialCalldata = abi.encodeWithSelector(
            fundsHandler.recordDeposit.selector,
            depositTaskParams[0]
        );
        signature = _generateOptSignature(taskOpts, tssKey);

        // check event and result
        vm.expectEmit(true, true, true, true);
        emit ITaskManager.TaskUpdated(taskIds, taskStates);
        entryPoint.verifyAndCall(taskOpts, signature);
        depositAmount = fundsHandler.getDeposit(
            DEFAULT_ACCOUNT,
            depositTaskParams[0].ticker,
            depositTaskParams[0].chainId,
            fundsHandler
                .getDeposits(
                    DEFAULT_ACCOUNT,
                    depositTaskParams[0].ticker,
                    depositTaskParams[0].chainId
                )
                .length - 1
        );
        assertEq(newAmount, depositAmount);
        assertEq(fundsHandler.totalValueLocked(TICKER), DEFAULT_AMOUNT + newAmount);
        vm.stopPrank();
    }

    function test_DepositTaskRevert() public {
        vm.startPrank(msgSender);
        depositTaskParams[0].amount = 0; // invalid amount
        // fail case: invalid amount
        vm.expectRevert("Invalid amount");
        fundsHandler.submitDepositTask(depositTaskParams);

        // fail case: invalid user address
        depositTaskParams.pop();
        vm.expectRevert("Empty input");
        fundsHandler.submitDepositTask(depositTaskParams);
        vm.stopPrank();
    }

    function test_DepositBatch() public {
        vm.startPrank(msgSender);
        uint8 batchSize = 20;
        // setup deposit info
        TaskOperation[] memory taskOperations = new TaskOperation[](batchSize);
        uint256[] memory amounts = new uint256[](batchSize);
        DepositParam[] memory batchDepositTaskParams = new DepositParam[](batchSize);
        for (uint8 i; i < batchSize; ++i) {
            amounts[i] = 1 ether;
            batchDepositTaskParams[i] = DepositParam(
                DEFAULT_ACCOUNT,
                CHAIN_ID,
                AddressCategory.EVM,
                TICKER,
                amounts[i],
                string(abi.encodePacked("txHash ", i)),
                100,
                0
            );
            taskOperations[i] = TaskOperation(
                i + 1,
                State.Pending,
                abi.encodeWithSelector(
                    fundsHandler.recordDeposit.selector,
                    batchDepositTaskParams[i]
                ),
                ""
            );
        }
        fundsHandler.submitDepositTask(batchDepositTaskParams);
        for (uint16 i; i < batchSize; ++i) {
            assertEq(
                uint8(taskManager.getTaskState(taskOperations[i].taskId)),
                uint8(State.Created)
            );
        }
        signature = _generateOptSignature(taskOperations, tssKey);
        entryPoint.verifyAndCall(taskOperations, signature);

        for (uint16 i; i < batchSize; ++i) {
            assertEq(
                uint8(taskManager.getTaskState(taskOperations[i].taskId)),
                uint8(State.Pending)
            );
            taskOperations[i].state = State.Completed;
        }
        signature = _generateOptSignature(taskOperations, tssKey);
        entryPoint.verifyAndCall(taskOperations, signature);
        for (uint8 i; i < batchSize; ++i) {
            assertEq(
                uint8(taskManager.getTaskState(taskOperations[i].taskId)),
                uint8(State.Completed)
            );
            uint256 depositAmount = fundsHandler.getDeposit(DEFAULT_ACCOUNT, TICKER, CHAIN_ID, i);
            assertEq(amounts[i], depositAmount);
        }
        vm.stopPrank();
    }

    function testFuzz_DepositFuzz(uint256 _amount, string calldata _txHash) public {
        vm.startPrank(msgSender);
        vm.assume(_amount > MIN_DEPOSIT_AMOUNT);
        vm.assume(bytes(_txHash).length > 0);
        // setup deposit info
        uint256 depositIndex = fundsHandler.getDeposits(DEFAULT_ACCOUNT, TICKER, CHAIN_ID).length;
        depositTaskParams[0].amount = _amount;
        depositTaskParams[0].txHash = _txHash;
        fundsHandler.submitDepositTask(depositTaskParams);

        taskOpts[0].initialCalldata = abi.encodeWithSelector(
            fundsHandler.recordDeposit.selector,
            depositTaskParams[0]
        );
        signature = _generateOptSignature(taskOpts, tssKey);

        // check event and result
        vm.expectEmit(true, true, true, true);
        emit ITaskManager.TaskUpdated(taskIds, taskStates);
        entryPoint.verifyAndCall(taskOpts, signature);
        uint256 depositAmount = fundsHandler.getDeposit(
            DEFAULT_ACCOUNT,
            TICKER,
            CHAIN_ID,
            depositIndex
        );
        assertEq(depositAmount, _amount);
        vm.stopPrank();
    }

    function test_Withdraw() public {
        vm.prank(entryPointProxy);
        fundsHandler.recordDeposit(depositTaskParams[0]);
        vm.startPrank(msgSender);
        assertEq(fundsHandler.totalValueLocked(TICKER), DEFAULT_AMOUNT);
        // setup withdrawal info
        uint256 withdrawIndex = fundsHandler
            .getWithdrawals(DEFAULT_ACCOUNT, TICKER, CHAIN_ID)
            .length;
        assertEq(withdrawIndex, 0);
        taskOpts[0].state = State.Pending;
        taskOpts[0].initialCalldata = abi.encodeWithSelector(
            fundsHandler.recordWithdrawal.selector,
            withdrawTaskParams[0].accountNumber,
            withdrawTaskParams[0].chainId,
            withdrawTaskParams[0].ticker,
            withdrawTaskParams[0].toAddress,
            withdrawTaskParams[0].amount,
            WITHDRAW_FEE,
            bytes32(uint256(0)),
            uint256(320)
        );

        bytes32[] memory dataHash = new bytes32[](1);
        dataHash[0] = keccak256(taskOpts[0].initialCalldata);
        uint256[] memory tokenAmount = new uint256[](1);
        tokenAmount[0] = (DEFAULT_AMOUNT - WITHDRAW_FEE) / 10 ** 12; // decimal difference (18 - 6)
        uint256[] memory withdrawFee = new uint256[](1);
        withdrawFee[0] = WITHDRAW_FEE; // decimal difference (18 - 6)
        vm.expectEmit();
        emit IFundsHandler.WithdrawRequest(dataHash, tokenAmount, withdrawFee);
        fundsHandler.submitWithdrawTask(withdrawTaskParams);

        // pending task
        signature = _generateOptSignature(taskOpts, tssKey);
        entryPoint.verifyAndCall(taskOpts, signature);

        // completed task
        taskOpts[0].state = State.Completed;
        taskOpts[0].extraData = TestHelper.getPaddedString(
            "--------------------------------txHash--------------------------------"
        );
        signature = _generateOptSignature(taskOpts, tssKey);
        // check event and result
        vm.expectEmit(true, true, true, true);
        emit ITaskManager.TaskUpdated(taskIds, taskStates);
        entryPoint.verifyAndCall(taskOpts, signature);
        uint256 withdrawAmount = fundsHandler.getWithdrawal(
            DEFAULT_ACCOUNT,
            TICKER,
            CHAIN_ID,
            withdrawIndex
        );
        assertEq(withdrawAmount, withdrawTaskParams[0].amount);
        assertEq(
            fundsHandler.totalValueLocked(TICKER),
            DEFAULT_AMOUNT - withdrawTaskParams[0].amount
        );
        vm.stopPrank();
    }

    function test_WithdrawRevert() public {
        vm.startPrank(msgSender);
        // setup withdraw info
        // fail case: invalid amount
        withdrawTaskParams[0].amount = 0; // invalid amount
        vm.expectRevert("Invalid amount");
        fundsHandler.submitWithdrawTask(withdrawTaskParams);

        // fail case: not enough to pay withdraw fee
        withdrawTaskParams[0].amount = WITHDRAW_FEE - 1; // invalid amount
        vm.expectRevert("Insufficient balance to pay fee");
        fundsHandler.submitWithdrawTask(withdrawTaskParams);

        // fail case: invalid deposit address
        withdrawTaskParams[0].amount = 1 ether;
        withdrawTaskParams[0].toAddress = "";
        vm.expectRevert("Invalid address");
        fundsHandler.submitWithdrawTask(withdrawTaskParams);

        // fail case: empty input array
        withdrawTaskParams.pop();
        vm.expectRevert("Empty input");
        fundsHandler.submitWithdrawTask(withdrawTaskParams);
        vm.stopPrank();
    }

    function test_WithdrawBatch() public {
        depositTaskParams[0].amount = type(uint256).max;
        vm.prank(entryPointProxy);
        fundsHandler.recordDeposit(depositTaskParams[0]);
        vm.startPrank(msgSender);
        uint8 batchSize = 20;
        // setup withdraw info
        TaskOperation[] memory taskOperations = new TaskOperation[](batchSize);
        uint256[] memory amounts = new uint256[](batchSize);
        WithdrawalParam[] memory batchWithdrawTaskParams = new WithdrawalParam[](batchSize);
        for (uint8 i; i < batchSize; ++i) {
            amounts[i] = 1 ether * (uint256(i) + 1);
            batchWithdrawTaskParams[i] = WithdrawalParam(
                DEFAULT_ACCOUNT,
                CHAIN_ID,
                AddressCategory.EVM,
                TICKER,
                DEPOSIT_ADDRESS,
                amounts[i],
                bytes32(uint256(i))
            );
            taskOperations[i] = TaskOperation(
                i + 1,
                State.Pending,
                abi.encodeWithSelector(
                    fundsHandler.recordWithdrawal.selector,
                    DEFAULT_ACCOUNT,
                    CHAIN_ID,
                    TICKER,
                    DEPOSIT_ADDRESS,
                    amounts[i],
                    WITHDRAW_FEE,
                    bytes32(uint256(i)),
                    uint256(320) + (32 * ((bytes(DEPOSIT_ADDRESS).length - 1) / 32))
                ),
                ""
            );
        }
        fundsHandler.submitWithdrawTask(batchWithdrawTaskParams);
        for (uint16 i; i < batchSize; ++i) {
            assertEq(
                uint8(taskManager.getTaskState(taskOperations[i].taskId)),
                uint8(State.Created)
            );
        }
        signature = _generateOptSignature(taskOperations, tssKey);
        entryPoint.verifyAndCall(taskOperations, signature);
        for (uint16 i; i < batchSize; ++i) {
            assertEq(
                uint8(taskManager.getTaskState(taskOperations[i].taskId)),
                uint8(State.Pending)
            );
            taskOperations[i].state = State.Completed;
            taskOperations[i].extraData = TestHelper.getPaddedString("txHash");
        }
        signature = _generateOptSignature(taskOperations, tssKey);
        entryPoint.verifyAndCall(taskOperations, signature);
        for (uint16 i; i < batchSize; ++i) {
            assertEq(
                uint8(taskManager.getTaskState(taskOperations[i].taskId)),
                uint8(State.Completed)
            );
            uint256 withdrawAmount = fundsHandler.getWithdrawal(
                DEFAULT_ACCOUNT,
                TICKER,
                CHAIN_ID,
                i
            );
            assertEq(withdrawAmount, amounts[i]);
        }
        vm.stopPrank();
    }

    function testFuzz_WithdrawFuzz(
        string calldata _toAddress,
        uint256 _amount,
        bytes32 _salt,
        string calldata _txHash
    ) public {
        vm.assume(bytes(_toAddress).length > 0);
        vm.assume(_amount < type(uint192).max);
        vm.assume(_amount > WITHDRAW_FEE);
        vm.assume(bytes(_txHash).length > 0);
        vm.prank(entryPointProxy);
        depositTaskParams[0].amount = type(uint256).max;
        fundsHandler.recordDeposit(depositTaskParams[0]);

        vm.startPrank(msgSender);
        // setup withdrawal info
        WithdrawalParam[] memory tempWithdrawTaskParams = new WithdrawalParam[](1);
        tempWithdrawTaskParams[0] = WithdrawalParam(
            DEFAULT_ACCOUNT,
            CHAIN_ID,
            AddressCategory.EVM,
            TICKER,
            _toAddress,
            _amount,
            _salt
        );
        fundsHandler.submitWithdrawTask(tempWithdrawTaskParams);

        // pending task
        taskOpts[0].state = State.Pending;
        taskOpts[0].initialCalldata = abi.encodeWithSelector(
            fundsHandler.recordWithdrawal.selector,
            DEFAULT_ACCOUNT,
            CHAIN_ID,
            TICKER,
            _toAddress,
            _amount,
            WITHDRAW_FEE,
            _salt,
            uint256(320) + (32 * ((bytes(_toAddress).length - 1) / 32))
        );
        signature = _generateOptSignature(taskOpts, tssKey);
        entryPoint.verifyAndCall(taskOpts, signature);

        // completed task
        taskOpts[0].state = State.Completed;
        taskOpts[0].extraData = TestHelper.getPaddedString(_txHash);
        signature = _generateOptSignature(taskOpts, tssKey);
        // check event and result
        vm.expectEmit(true, true, true, true);
        emit ITaskManager.TaskUpdated(taskIds, taskStates);
        entryPoint.verifyAndCall(taskOpts, signature);
        vm.stopPrank();
    }

    function test_Consolidate() public {
        vm.startPrank(msgSender);
        string memory fromAddr = "0xFromAddress";
        uint256 amount = 1 ether;
        string memory txHash = "consolidate_txHash";
        ConsolidateTaskParam[] memory consolidateParams = new ConsolidateTaskParam[](1);

        // empty from address
        consolidateParams[0] = ConsolidateTaskParam(
            "",
            TICKER,
            CHAIN_ID,
            CHAIN_ID,
            amount,
            bytes32(uint256(0))
        );
        vm.expectRevert("Invalid address");
        fundsHandler.submitConsolidateTask(consolidateParams);

        // below minimum amount
        consolidateParams[0] = ConsolidateTaskParam(
            fromAddr,
            TICKER,
            CHAIN_ID,
            CHAIN_ID,
            0,
            bytes32(uint256(0))
        );
        vm.expectRevert("Invalid amount");
        fundsHandler.submitConsolidateTask(consolidateParams);

        // correct amount
        consolidateParams[0] = ConsolidateTaskParam(
            fromAddr,
            TICKER,
            CHAIN_ID,
            CHAIN_ID,
            amount,
            bytes32(uint256(0))
        );
        fundsHandler.submitConsolidateTask(consolidateParams);
        taskOpts[0].extraData = TestHelper.getPaddedString(txHash);
        signature = _generateOptSignature(taskOpts, tssKey);

        vm.expectEmit(true, true, true, true);
        emit ITaskManager.TaskUpdated(taskIds, taskStates);
        entryPoint.verifyAndCall(taskOpts, signature);
        vm.stopPrank();
    }

    function test_Transfer() public {
        vm.startPrank(msgSender);
        string memory fromAddr = "0xFromAddress";
        string memory toAddr = "0xToAddress";
        uint256 amount = 1 ether;
        string memory txHash = "transfer_txHash";
        TransferParam[] memory transferParams = new TransferParam[](1);

        // empty from address
        transferParams[0] = TransferParam(
            "",
            toAddr,
            TICKER,
            CHAIN_ID,
            amount,
            bytes32(uint256(0))
        );
        vm.expectRevert("Invalid address");
        fundsHandler.submitTransferTask(transferParams);

        // empty from address
        transferParams[0] = TransferParam(
            fromAddr,
            "",
            TICKER,
            CHAIN_ID,
            amount,
            bytes32(uint256(1))
        );
        vm.expectRevert("Invalid address");
        fundsHandler.submitTransferTask(transferParams);

        // below minimum amount
        transferParams[0] = TransferParam(
            fromAddr,
            toAddr,
            TICKER,
            CHAIN_ID,
            0,
            bytes32(uint256(2))
        );
        vm.expectRevert("Invalid amount");
        fundsHandler.submitTransferTask(transferParams);

        // correct amount
        transferParams[0] = TransferParam(
            fromAddr,
            toAddr,
            TICKER,
            CHAIN_ID,
            amount,
            bytes32(uint256(3))
        );
        fundsHandler.submitTransferTask(transferParams);
        taskOpts[0].extraData = TestHelper.getPaddedString(txHash);
        signature = _generateOptSignature(taskOpts, tssKey);
        entryPoint.verifyAndCall(taskOpts, signature);
        vm.stopPrank();
    }
}
