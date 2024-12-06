pragma solidity ^0.8.0;

import "./BaseTest.sol";

import {AccountHandlerUpgradeable} from "../src/handlers/AccountHandlerUpgradeable.sol";
import {IAccountHandler} from "../src/interfaces/IAccountHandler.sol";
import {ITaskManager} from "../src/interfaces/ITaskManager.sol";

contract AccountCreationTest is BaseTest {
    string public depositAddress;

    AccountHandlerUpgradeable public accountHandler;
    address public amProxy;

    uint256 constant DEFAULT_ACCOUNT = 10001;

    function setUp() public override {
        super.setUp();
        depositAddress = "new_address";

        // deploy accountHandler
        amProxy = _deployProxy(address(new AccountHandlerUpgradeable()), daoContract);
        accountHandler = AccountHandlerUpgradeable(amProxy);
        accountHandler.initialize(vmProxy);
        assertEq(accountHandler.owner(), vmProxy);

        // initialize entryPoint link to all contracts
        entryPoint = EntryPointUpgradeable(vmProxy);
        entryPoint.initialize(
            tssSigner, // tssSigner
            address(participantHandler), // participantHandler
            address(taskManager), // taskManager
            address(nuvoLock) // nuvoLock
        );
    }

    function test_Create() public {
        vm.startPrank(msgSender);
        // submit task
        uint64 taskId = taskSubmitter.submitTask(_generateTaskContext());
        // process after tss picked up the task
        bytes memory callData = abi.encodeWithSelector(
            IAccountHandler.registerNewAddress.selector,
            DEFAULT_ACCOUNT,
            IAccountHandler.Chain.BTC,
            0,
            depositAddress
        );
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(amProxy, State.Completed, taskId, callData);
        bytes memory signature = _generateSignature(opts, tssKey);
        entryPoint.verifyAndCall(opts, signature);

        // check mappings|reverseMapping
        assertEq(
            accountHandler.getAddressRecord(DEFAULT_ACCOUNT, IAccountHandler.Chain.BTC, uint(0)),
            depositAddress
        );
        assertEq(
            accountHandler.addressRecord(
                abi.encodePacked(DEFAULT_ACCOUNT, IAccountHandler.Chain.BTC, uint(0))
            ),
            depositAddress
        );
        assertEq(
            accountHandler.userMapping(depositAddress, IAccountHandler.Chain.BTC),
            DEFAULT_ACCOUNT
        );

        // fail: already registered
        taskId = taskSubmitter.submitTask(_generateTaskContext());
        opts[0] = Operation(amProxy, State.Completed, taskId, callData);
        signature = _generateSignature(opts, tssKey);

        vm.expectEmit(true, true, true, true);
        emit IEntryPoint.OperationFailed(
            abi.encodeWithSelector(
                IAccountHandler.RegisteredAccount.selector,
                DEFAULT_ACCOUNT,
                accountHandler.addressRecord(
                    abi.encodePacked(DEFAULT_ACCOUNT, IAccountHandler.Chain.BTC, uint(0))
                )
            )
        );
        entryPoint.verifyAndCall(opts, signature);
        vm.stopPrank();
    }

    function test_CreateRevert() public {
        // fail case: deposit address as address zero
        uint64 taskId = taskSubmitter.submitTask(_generateTaskContext());
        bytes memory callData = abi.encodeWithSelector(
            IAccountHandler.registerNewAddress.selector,
            DEFAULT_ACCOUNT,
            IAccountHandler.Chain.BTC,
            uint(0),
            ""
        );
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(amProxy, State.Completed, taskId, callData);
        bytes memory signature = _generateSignature(opts, tssKey);
        vm.expectEmit(true, true, true, true);
        emit IEntryPoint.OperationFailed(
            abi.encodeWithSelector((IAccountHandler.InvalidAddress.selector))
        );
        vm.prank(msgSender);
        entryPoint.verifyAndCall(opts, signature);

        // fail case: account number less than 10000
        taskId = taskSubmitter.submitTask(_generateTaskContext());
        callData = abi.encodeWithSelector(
            IAccountHandler.registerNewAddress.selector,
            uint(9999),
            IAccountHandler.Chain.BTC,
            uint(0),
            depositAddress
        );
        opts[0] = Operation(amProxy, State.Completed, taskId, callData);
        signature = _generateSignature(opts, tssKey);
        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true);
        emit IEntryPoint.OperationFailed(
            abi.encodeWithSelector(IAccountHandler.InvalidAccountNumber.selector, 9999)
        );
        entryPoint.verifyAndCall(opts, signature);
    }

    function testFuzz_CreateFuzz(
        uint256 _account,
        uint8 _chain,
        uint256 _index,
        string calldata _address
    ) public {
        vm.assume(_account < 10000000);
        vm.assume(_chain < 3);
        vm.assume(bytes(_address).length > 0);
        IAccountHandler.Chain chain = IAccountHandler.Chain(_chain);
        vm.startPrank(address(entryPoint));
        if (_account > 10000) {
            accountHandler.registerNewAddress(_account, chain, _index, _address);
            // check mappings|reverseMapping
            assertEq(
                accountHandler.addressRecord(abi.encodePacked(_account, chain, _index)),
                _address
            );
            assertEq(accountHandler.userMapping(_address, chain), _account);
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(IAccountHandler.InvalidAccountNumber.selector, _account)
            );
            accountHandler.registerNewAddress(_account, chain, _index, _address);
            vm.stopPrank();
        }
    }
}
