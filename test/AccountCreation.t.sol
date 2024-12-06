pragma solidity ^0.8.0;

import "./BaseTest.sol";

import {AccountManagerUpgradeable} from "../src/handlers/AccountManagerUpgradeable.sol";
import {IAccountManager} from "../src/interfaces/IAccountManager.sol";
import {ITaskManager} from "../src/interfaces/ITaskManager.sol";

contract AccountCreation is BaseTest {
    string public depositAddress;

    AccountManagerUpgradeable public accountManager;
    address public amProxy;

    uint256 constant DEFAULT_ACCOUNT = 10001;

    function setUp() public override {
        super.setUp();
        depositAddress = "new_address";

        // deploy accountManager
        amProxy = _deployProxy(address(new AccountManagerUpgradeable()), daoContract);
        accountManager = AccountManagerUpgradeable(amProxy);
        accountManager.initialize(vmProxy);
        assertEq(accountManager.owner(), vmProxy);

        // initialize votingManager link to all contracts
        votingManager = EntryPointUpgradeable(vmProxy);
        votingManager.initialize(
            tssSigner, // tssSigner
            address(participantManager), // participantManager
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
            IAccountManager.registerNewAddress.selector,
            DEFAULT_ACCOUNT,
            IAccountManager.Chain.BTC,
            0,
            depositAddress
        );
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(amProxy, State.Completed, taskId, callData);
        bytes memory signature = _generateSignature(opts, tssKey);
        votingManager.verifyAndCall(opts, signature);

        // check mappings|reverseMapping
        assertEq(
            accountManager.getAddressRecord(DEFAULT_ACCOUNT, IAccountManager.Chain.BTC, uint(0)),
            depositAddress
        );
        assertEq(
            accountManager.addressRecord(
                abi.encodePacked(DEFAULT_ACCOUNT, IAccountManager.Chain.BTC, uint(0))
            ),
            depositAddress
        );
        assertEq(
            accountManager.userMapping(depositAddress, IAccountManager.Chain.BTC),
            DEFAULT_ACCOUNT
        );

        // fail: already registered
        taskId = taskSubmitter.submitTask(_generateTaskContext());
        opts[0] = Operation(amProxy, State.Completed, taskId, callData);
        signature = _generateSignature(opts, tssKey);

        vm.expectEmit(true, true, true, true);
        emit IVotingManager.OperationFailed(
            abi.encodeWithSelector(
                IAccountManager.RegisteredAccount.selector,
                DEFAULT_ACCOUNT,
                accountManager.addressRecord(
                    abi.encodePacked(DEFAULT_ACCOUNT, IAccountManager.Chain.BTC, uint(0))
                )
            )
        );
        votingManager.verifyAndCall(opts, signature);
        vm.stopPrank();
    }

    function test_CreateRevert() public {
        // fail case: deposit address as address zero
        uint64 taskId = taskSubmitter.submitTask(_generateTaskContext());
        bytes memory callData = abi.encodeWithSelector(
            IAccountManager.registerNewAddress.selector,
            DEFAULT_ACCOUNT,
            IAccountManager.Chain.BTC,
            uint(0),
            ""
        );
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(amProxy, State.Completed, taskId, callData);
        bytes memory signature = _generateSignature(opts, tssKey);
        vm.expectEmit(true, true, true, true);
        emit IVotingManager.OperationFailed(
            abi.encodeWithSelector((IAccountManager.InvalidAddress.selector))
        );
        vm.prank(msgSender);
        votingManager.verifyAndCall(opts, signature);

        // fail case: account number less than 10000
        taskId = taskSubmitter.submitTask(_generateTaskContext());
        callData = abi.encodeWithSelector(
            IAccountManager.registerNewAddress.selector,
            uint(9999),
            IAccountManager.Chain.BTC,
            uint(0),
            depositAddress
        );
        opts[0] = Operation(amProxy, State.Completed, taskId, callData);
        signature = _generateSignature(opts, tssKey);
        vm.prank(msgSender);
        vm.expectEmit(true, true, true, true);
        emit IVotingManager.OperationFailed(
            abi.encodeWithSelector(IAccountManager.InvalidAccountNumber.selector, 9999)
        );
        votingManager.verifyAndCall(opts, signature);
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
        IAccountManager.Chain chain = IAccountManager.Chain(_chain);
        vm.startPrank(address(votingManager));
        if (_account > 10000) {
            accountManager.registerNewAddress(_account, chain, _index, _address);
            // check mappings|reverseMapping
            assertEq(
                accountManager.addressRecord(abi.encodePacked(_account, chain, _index)),
                _address
            );
            assertEq(accountManager.userMapping(_address, chain), _account);
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(IAccountManager.InvalidAccountNumber.selector, _account)
            );
            accountManager.registerNewAddress(_account, chain, _index, _address);
            vm.stopPrank();
        }
    }
}
