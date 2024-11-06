pragma solidity ^0.8.0;

import {BaseTest, console} from "./BaseTest.sol";

import {AccountManagerUpgradeable} from "../src/AccountManagerUpgradeable.sol";
import {IAccountManager} from "../src/interfaces/IAccountManager.sol";
import {ITaskManager} from "../src/interfaces/ITaskManager.sol";
import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";

contract AccountCreation is BaseTest {
    string public depositAddress;

    AccountManagerUpgradeable public accountManager;
    address public amProxy;

    bytes public constant TASK_CONTEXT = "--- encoded account creation task context ---";

    function setUp() public override {
        super.setUp();
        depositAddress = "new_address";

        // deploy accountManager
        amProxy = _deployProxy(address(new AccountManagerUpgradeable()), daoContract);
        accountManager = AccountManagerUpgradeable(amProxy);
        accountManager.initialize(vmProxy);
        assertEq(accountManager.owner(), vmProxy);

        // initialize votingManager link to all contracts
        votingManager = VotingManagerUpgradeable(vmProxy);
        votingManager.initialize(
            tssSigner,
            amProxy, // accountManager
            address(0), // assetManager
            address(0), // depositManager
            address(participantManager), // participantManager
            address(taskManager), // taskManager
            address(nuvoLock) // nuvoLock
        );
    }

    function test_Create() public {
        vm.startPrank(msgSender);
        // submit task
        uint256 taskId = taskSubmitter.submitTask(TASK_CONTEXT);

        // process after tss picked up the task
        bytes memory callData = abi.encodeWithSelector(
            IAccountManager.registerNewAddress.selector,
            msgSender,
            10001,
            IAccountManager.Chain.BTC,
            0,
            depositAddress
        );
        bytes memory signature = _generateSignature(amProxy, callData, taskId, tssKey);
        votingManager.verifyAndCall(amProxy, callData, taskId, signature);

        // check mappings|reverseMapping
        assertEq(
            accountManager.getAddressRecord(
                msgSender,
                uint(10001),
                IAccountManager.Chain.BTC,
                uint(0)
            ),
            depositAddress
        );
        assertEq(
            accountManager.addressRecord(
                abi.encodePacked(msgSender, uint(10001), IAccountManager.Chain.BTC, uint(0))
            ),
            depositAddress
        );
        assertEq(accountManager.userMapping(depositAddress, IAccountManager.Chain.BTC), msgSender);

        // fail: already registered
        taskId = taskSubmitter.submitTask(TASK_CONTEXT);
        signature = _generateSignature(amProxy, callData, taskId, tssKey);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccountManager.RegisteredAccount.selector,
                msgSender,
                accountManager.addressRecord(
                    abi.encodePacked(msgSender, uint(10001), IAccountManager.Chain.BTC, uint(0))
                )
            )
        );
        votingManager.verifyAndCall(amProxy, callData, taskId, signature);
        vm.stopPrank();
    }

    function test_CreateRevert() public {
        // fail case: msg.sender not the owner
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("OwnableUnauthorizedAccount(address)")),
                thisAddr
            )
        );
        accountManager.registerNewAddress(
            msgSender,
            10001,
            IAccountManager.Chain.BTC,
            0,
            depositAddress
        );

        // fail case: deposit address as address zero
        uint256 taskId = taskSubmitter.submitTask(TASK_CONTEXT);
        bytes memory callData = abi.encodeWithSelector(
            IAccountManager.registerNewAddress.selector,
            msgSender,
            uint(10001),
            IAccountManager.Chain.BTC,
            uint(0),
            ""
        );
        bytes memory signature = _generateSignature(amProxy, callData, taskId, tssKey);
        vm.prank(msgSender);
        vm.expectRevert(IAccountManager.InvalidAddress.selector);
        votingManager.verifyAndCall(amProxy, callData, taskId, signature);

        // fail case: account number less than 10000
        callData = abi.encodeWithSelector(
            IAccountManager.registerNewAddress.selector,
            msgSender,
            uint(9999),
            IAccountManager.Chain.BTC,
            uint(0),
            depositAddress
        );
        signature = _generateSignature(amProxy, callData, taskId, tssKey);
        vm.prank(msgSender);
        vm.expectRevert(
            abi.encodeWithSelector(IAccountManager.InvalidAccountNumber.selector, 9999)
        );
        votingManager.verifyAndCall(amProxy, callData, taskId, signature);
    }
}
