pragma solidity ^0.8.0;

import {BaseTest} from "./BaseTest.sol";

import {AccountManagerUpgradeable} from "../src/AccountManagerUpgradeable.sol";
import {IAccountManager} from "../src/interfaces/IAccountManager.sol";
import {NuDexOperationsUpgradeable} from "../src/NuDexOperationsUpgradeable.sol";
import {INuDexOperations} from "../src/interfaces/INuDexOperations.sol";
import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";

import {MockParticipantManager} from "../src/mocks/MockParticipantManager.sol";
import {MockNuvoLockUpgradeable} from "../src/mocks/MockNuvoLockUpgradeable.sol";

contract AccountCreation is BaseTest {
    address public depositAddress;

    AccountManagerUpgradeable public accountManager;
    NuDexOperationsUpgradeable public nuDexOperations;
    MockParticipantManager public participantManager;
    MockNuvoLockUpgradeable public nuvoLock;

    function setUp() public override {
        super.setUp();
        depositAddress = makeAddr("new_address");

        // deploy mock contract
        participantManager = new MockParticipantManager(msgSender);
        nuvoLock = new MockNuvoLockUpgradeable();

        // deploy votingManager proxy
        address vmProxy = deployProxy(address(new VotingManagerUpgradeable()), daoContract);

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
        bytes memory encodedParams = abi.encodePacked(
            msgSender,
            uint(10001),
            IAccountManager.Chain.BTC,
            uint(0),
            depositAddress
        );
        bytes memory signature = generateSignature(encodedParams, tssKey);

        votingManager.registerAccount(
            msgSender,
            10001,
            IAccountManager.Chain.BTC,
            0,
            depositAddress,
            signature
        );

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
        vm.expectRevert(IAccountManager.RegisteredAccount.selector);
        votingManager.registerAccount(
            msgSender,
            10001,
            IAccountManager.Chain.BTC,
            0,
            depositAddress,
            signature
        );

        // finialize task
        bytes memory taskResult = "--- encoded task result ---";
        encodedParams = abi.encodePacked(taskId, taskResult);
        signature = generateSignature(encodedParams, tssKey);
        vm.expectEmit(true, true, true, true);
        emit INuDexOperations.TaskCompleted(taskId, msgSender, block.timestamp, taskResult);
        votingManager.submitTaskReceipt(taskId, taskResult, signature);
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
        bytes memory encodedParams = abi.encodePacked(
            msgSender,
            uint(10001),
            IAccountManager.Chain.BTC,
            uint(0),
            address(0)
        );
        bytes memory signature = generateSignature(encodedParams, tssKey);
        vm.prank(msgSender);
        vm.expectRevert(IAccountManager.InvalidAddress.selector);
        votingManager.registerAccount(
            msgSender,
            10001,
            IAccountManager.Chain.BTC,
            0,
            address(0),
            signature
        );

        // fail case: account number less than 10000
        encodedParams = abi.encodePacked(
            msgSender,
            uint(9999),
            IAccountManager.Chain.BTC,
            uint(0),
            depositAddress
        );
        signature = generateSignature(encodedParams, tssKey);
        vm.prank(msgSender);
        vm.expectRevert(IAccountManager.InvalidAccountNumber.selector);
        votingManager.registerAccount(
            msgSender,
            9999,
            IAccountManager.Chain.BTC,
            0,
            depositAddress,
            signature
        );
    }
}
