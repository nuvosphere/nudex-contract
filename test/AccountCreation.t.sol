pragma solidity ^0.8.0;

import {BaseTest, console} from "./BaseTest.sol";

import {AccountManagerUpgradeable} from "../src/AccountManagerUpgradeable.sol";
import {IAccountManager} from "../src/interfaces/IAccountManager.sol";
import {NuDexOperationsUpgradeable} from "../src/NuDexOperationsUpgradeable.sol";
import {INuDexOperations} from "../src/interfaces/INuDexOperations.sol";
import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";

contract AccountCreation is BaseTest {
    string public depositAddress;

    AccountManagerUpgradeable public accountManager;
    NuDexOperationsUpgradeable public nuDexOperations;

    function setUp() public override {
        super.setUp();
        depositAddress = "new_address";

        // deploy nuDexOperations
        address operationProxy = deployProxy(
            address(new NuDexOperationsUpgradeable()),
            daoContract
        );
        nuDexOperations = NuDexOperationsUpgradeable(operationProxy);
        nuDexOperations.initialize(address(participantManager), vmProxy);
        assertEq(nuDexOperations.owner(), vmProxy);

        // deploy accountManager
        address amProxy = deployProxy(address(new AccountManagerUpgradeable()), daoContract);
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
            operationProxy, // nudeOperation
            address(nuvoLock) // nuvoLock
        );
    }

    function test_Create() public {
        vm.startPrank(msgSender);
        // submit task
        uint256 taskId = nuDexOperations.nextTaskId();
        bytes memory taskContext = "--- encoded account creation task context ---";
        vm.expectEmit(true, true, true, true);
        emit INuDexOperations.TaskSubmitted(taskId, taskContext, msgSender);
        nuDexOperations.submitTask(taskContext);
        assertEq(taskId, nuDexOperations.nextTaskId() - 1);

        // process after tss picked up the task
        bytes memory callData = abi.encodeWithSelector(
            IAccountManager.registerNewAddress.selector,
            msgSender,
            10001,
            IAccountManager.Chain.BTC,
            0,
            depositAddress
        );
        bytes memory signature = generateSignature(callData, tssKey);
        votingManager.verifyAndCall(address(accountManager), callData, signature);

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

        // revert if using the same signature
        vm.expectPartialRevert(VotingManagerUpgradeable.InvalidSigner.selector);
        votingManager.verifyAndCall(address(accountManager), callData, signature);

        signature = generateSignature(callData, tssKey);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccountManager.RegisteredAccount.selector,
                msgSender,
                accountManager.addressRecord(
                    abi.encodePacked(msgSender, uint(10001), IAccountManager.Chain.BTC, uint(0))
                )
            )
        );
        votingManager.verifyAndCall(address(accountManager), callData, signature);

        // finialize task
        bytes memory taskResult = "--- encoded task result ---";
        callData = abi.encodeWithSelector(
            INuDexOperations.markTaskCompleted.selector,
            taskId,
            taskResult
        );
        signature = generateSignature(callData, tssKey);
        vm.expectEmit(true, true, true, true);
        emit INuDexOperations.TaskCompleted(taskId, msgSender, block.timestamp, taskResult);
        votingManager.verifyAndCall(address(nuDexOperations), callData, signature);
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
        bytes memory callData = abi.encodeWithSelector(
            IAccountManager.registerNewAddress.selector,
            msgSender,
            uint(10001),
            IAccountManager.Chain.BTC,
            uint(0),
            ""
        );
        bytes memory signature = generateSignature(callData, tssKey);
        vm.prank(msgSender);
        vm.expectRevert(IAccountManager.InvalidAddress.selector);
        votingManager.verifyAndCall(address(accountManager), callData, signature);

        // fail case: account number less than 10000
        callData = abi.encodeWithSelector(
            IAccountManager.registerNewAddress.selector,
            msgSender,
            uint(9999),
            IAccountManager.Chain.BTC,
            uint(0),
            depositAddress
        );
        signature = generateSignature(callData, tssKey);
        vm.prank(msgSender);
        vm.expectRevert(
            abi.encodeWithSelector(IAccountManager.InvalidAccountNumber.selector, 9999)
        );
        votingManager.verifyAndCall(address(accountManager), callData, signature);
    }
}
