pragma solidity ^0.8.0;

import "./BaseTest.sol";

import {AssetHandlerUpgradeable, AssetParam, AssetType, TokenInfo} from "../src/handlers/AssetHandlerUpgradeable.sol";
import {FundsHandlerUpgradeable} from "../src/handlers/FundsHandlerUpgradeable.sol";
import {IFundsHandler} from "../src/interfaces/IFundsHandler.sol";
import {ITaskManager} from "../src/interfaces/ITaskManager.sol";

contract FundsTest is BaseTest {
    bytes32 public constant TICKER = "TOKEN_TICKER_18";
    bytes32 public constant FUNDS_ROLE = keccak256("FUNDS_ROLE");
    bytes32 public constant CHAIN_ID = 0;
    uint256 public constant MIN_DEPOSIT_AMOUNT = 50;
    uint256 public constant MIN_WITHDRAW_AMOUNT = 50;

    address public user;

    FundsHandlerUpgradeable public fundsHandler;

    address public dmProxy;

    function setUp() public override {
        super.setUp();
        user = makeAddr("user");

        // setup assetHandler
        address ahProxy = _deployProxy(
            address(new AssetHandlerUpgradeable(address(taskManager))),
            daoContract
        );
        AssetHandlerUpgradeable assetHandler = AssetHandlerUpgradeable(ahProxy);
        assetHandler.initialize(thisAddr, msgSender);
        AssetParam memory assetParam = AssetParam(
            AssetType.EVM,
            18,
            true,
            true,
            MIN_DEPOSIT_AMOUNT,
            MIN_WITHDRAW_AMOUNT,
            "",
            ""
        );
        assetHandler.listNewAsset(TICKER, assetParam);
        TokenInfo[] memory testTokenInfo = new TokenInfo[](1);
        testTokenInfo[0] = TokenInfo(
            CHAIN_ID,
            true,
            AssetType.BTC,
            uint8(18),
            address(0),
            "SYMBOL",
            0,
            100 ether,
            100 ether
        );
        assetHandler.linkToken(TICKER, testTokenInfo);
        // deploy fundsHandler
        dmProxy = _deployProxy(
            address(new FundsHandlerUpgradeable(ahProxy, address(taskManager))),
            daoContract
        );
        fundsHandler = FundsHandlerUpgradeable(dmProxy);
        fundsHandler.initialize(vmProxy, msgSender);
        assertTrue(fundsHandler.hasRole(DEFAULT_ADMIN_ROLE, vmProxy));

        // assign handlers
        assetHandler.grantRole(FUNDS_ROLE, dmProxy);
        handlers.push(dmProxy);
        taskManager.initialize(vmProxy, handlers);

        // initialize entryPoint link to all contracts
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
        uint256 depositIndex = fundsHandler.getDeposits(user).length;
        assertEq(depositIndex, 0);
        bytes32 chainId = CHAIN_ID;
        uint256 depositAmount = 1 ether;
        taskIds[0] = fundsHandler.submitDepositTask(user, TICKER, chainId, depositAmount);
        bytes memory signature = _generateOptSignature(taskIds, tssKey);
        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IFundsHandler.DepositRecorded(user, TICKER, chainId, depositAmount);
        entryPoint.verifyAndCall(taskIds, signature);

        IFundsHandler.DepositInfo memory depositInfo = fundsHandler.getDeposit(user, depositIndex);
        assertEq(
            abi.encodePacked(user, TICKER, chainId, depositAmount),
            abi.encodePacked(
                depositInfo.userAddress,
                depositInfo.ticker,
                depositInfo.chainId,
                depositInfo.amount
            )
        );

        // second deposit
        // setup deposit info
        depositIndex = fundsHandler.getDeposits(user).length;
        assertEq(depositIndex, 1); // should have increased by 1
        chainId = bytes32(uint256(1));
        depositAmount = 5 ether;
        taskIds[0] = fundsHandler.submitDepositTask(user, TICKER, chainId, depositAmount);
        signature = _generateOptSignature(taskIds, tssKey);

        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IFundsHandler.DepositRecorded(user, TICKER, chainId, depositAmount);
        entryPoint.verifyAndCall(taskIds, signature);
        depositInfo = fundsHandler.getDeposit(user, depositIndex);
        assertEq(
            abi.encodePacked(user, TICKER, chainId, depositAmount),
            abi.encodePacked(
                depositInfo.userAddress,
                depositInfo.ticker,
                depositInfo.chainId,
                depositInfo.amount
            )
        );
        vm.stopPrank();
    }

    function test_DepositTaskRevert() public {
        vm.startPrank(msgSender);
        bytes32 chainId = CHAIN_ID;
        uint256 depositAmount = 0; // invalid amount
        // fail case: invalid amount
        vm.expectRevert(IFundsHandler.InvalidAmount.selector);
        taskIds[0] = fundsHandler.submitDepositTask(user, TICKER, chainId, depositAmount);

        // fail case: invalid user address
        depositAmount = 1 ether;
        user = address(0);
        vm.expectRevert(IFundsHandler.InvalidAddress.selector);
        taskIds[0] = fundsHandler.submitDepositTask(user, TICKER, chainId, depositAmount);
        vm.stopPrank();

        user = msgSender;
        vm.prank(vmProxy);
        fundsHandler.setPauseState(TICKER, true);
        vm.expectRevert(IFundsHandler.Paused.selector);
        vm.prank(msgSender);
        taskIds[0] = fundsHandler.submitDepositTask(user, TICKER, chainId, depositAmount);
    }

    function test_DepositBatch() public {
        vm.startPrank(msgSender);
        uint8 batchSize = 20;
        // setup deposit info
        bytes memory callData;
        uint64[] memory taskIds = new uint64[](batchSize);
        address[] memory users = new address[](batchSize);
        uint256[] memory amounts = new uint256[](batchSize);
        for (uint8 i; i < batchSize; ++i) {
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            amounts[i] = 1 ether;
            taskIds[i] = fundsHandler.submitDepositTask(users[i], TICKER, CHAIN_ID, amounts[i]);
        }
        for (uint16 i; i < batchSize; ++i) {
            assertEq(uint8(taskManager.getTaskState(taskIds[i])), uint8(State.Created));
        }
        bytes memory signature = _generateOptSignature(taskIds, tssKey);
        entryPoint.verifyAndCall(taskIds, signature);
        IFundsHandler.DepositInfo memory depositInfo;
        for (uint8 i; i < batchSize; ++i) {
            // assertEq(uint8(taskManager.getTaskState(taskIds[i])), uint8(State.Completed));
            depositInfo = fundsHandler.getDeposit(users[i], 0);
            assertEq(
                abi.encodePacked(users[i], amounts[i]),
                abi.encodePacked(depositInfo.userAddress, depositInfo.amount)
            );
        }
        vm.stopPrank();
    }

    function testFuzz_DepositFuzz(address _user, uint256 _amount) public {
        vm.startPrank(msgSender);
        vm.assume(_user != address(0));
        vm.assume(_amount > 0);
        // setup deposit info
        bytes32 chainId = CHAIN_ID;
        uint256 depositIndex = fundsHandler.getDeposits(user).length;
        taskIds[0] = fundsHandler.submitDepositTask(_user, TICKER, chainId, _amount);
        bytes memory signature = _generateOptSignature(taskIds, tssKey);

        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IFundsHandler.DepositRecorded(_user, TICKER, chainId, _amount);
        entryPoint.verifyAndCall(taskIds, signature);
        IFundsHandler.DepositInfo memory depositInfo = fundsHandler.getDeposit(_user, depositIndex);
        assertEq(
            abi.encodePacked(_user, TICKER, chainId, _amount),
            abi.encodePacked(
                depositInfo.userAddress,
                depositInfo.ticker,
                depositInfo.chainId,
                depositInfo.amount
            )
        );
        vm.stopPrank();
    }

    function test_Withdraw() public {
        vm.startPrank(msgSender);
        // setup withdrawal info
        uint256 withdrawIndex = fundsHandler.getWithdrawals(user).length;
        assertEq(withdrawIndex, 0);
        bytes32 chainId = CHAIN_ID;
        uint256 withdrawAmount = 1 ether;
        taskIds[0] = fundsHandler.submitWithdrawTask(user, TICKER, chainId, withdrawAmount);
        bytes memory signature = _generateOptSignature(taskIds, tssKey);
        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IFundsHandler.WithdrawalRecorded(user, TICKER, chainId, withdrawAmount);
        entryPoint.verifyAndCall(taskIds, signature);
        IFundsHandler.WithdrawalInfo memory withdrawInfo = fundsHandler.getWithdrawal(
            user,
            withdrawIndex
        );
        assertEq(
            abi.encodePacked(user, chainId, withdrawAmount),
            abi.encodePacked(withdrawInfo.userAddress, withdrawInfo.chainId, withdrawInfo.amount)
        );
        vm.stopPrank();
    }

    function test_WithdrawRevert() public {
        vm.startPrank(msgSender);
        // setup withdraw info
        bytes32 chainId = CHAIN_ID;
        uint256 withdrawAmount = 0; // invalid amount
        // fail case: invalid amount
        vm.expectRevert(IFundsHandler.InvalidAmount.selector);
        taskIds[0] = fundsHandler.submitWithdrawTask(user, TICKER, chainId, withdrawAmount);
        // fail case: invalid user address
        withdrawAmount = 1 ether;
        user = address(0);
        vm.expectRevert(IFundsHandler.InvalidAddress.selector);
        taskIds[0] = fundsHandler.submitWithdrawTask(user, TICKER, chainId, withdrawAmount);
        vm.stopPrank();

        user = msgSender;
        vm.prank(vmProxy);
        fundsHandler.setPauseState(TICKER, true);
        vm.expectRevert(IFundsHandler.Paused.selector);
        vm.prank(msgSender);
        taskIds[0] = fundsHandler.submitWithdrawTask(user, TICKER, chainId, withdrawAmount);
    }

    function test_WithdrawBatch() public {
        vm.startPrank(msgSender);
        uint8 batchSize = 20;
        // setup withdraw info
        bytes memory callData;
        uint64[] memory taskIds = new uint64[](batchSize);
        address[] memory users = new address[](batchSize);
        uint256[] memory amounts = new uint256[](batchSize);
        for (uint16 i; i < batchSize; ++i) {
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            amounts[i] = 1 ether;
            taskIds[i] = fundsHandler.submitWithdrawTask(users[i], TICKER, CHAIN_ID, amounts[i]);
        }
        bytes memory signature = _generateOptSignature(taskIds, tssKey);
        for (uint16 i; i < batchSize; ++i) {
            assertEq(uint8(taskManager.getTaskState(taskIds[i])), uint8(State.Created));
        }
        entryPoint.verifyAndCall(taskIds, signature);
        IFundsHandler.WithdrawalInfo memory withdrawalInfo;
        for (uint16 i; i < batchSize; ++i) {
            assertEq(uint8(taskManager.getTaskState(taskIds[i])), uint8(State.Completed));
            withdrawalInfo = fundsHandler.getWithdrawal(users[i], 0);
            assertEq(
                abi.encodePacked(users[i], amounts[i]),
                abi.encodePacked(withdrawalInfo.userAddress, withdrawalInfo.amount)
            );
        }
        vm.stopPrank();
    }
}
