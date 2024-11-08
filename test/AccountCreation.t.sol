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

    function test_DepositBatch() public {
        vm.startPrank(msgSender);
        uint16 batchSize = 20;

        // setup deposit info
        uint256[] memory taskIds = new uint256[](batchSize);
        address[] memory users = new address[](batchSize);
        uint256[] memory accounts = new uint256[](batchSize);
        IAccountManager.Chain[] memory chains = new IAccountManager.Chain[](batchSize);
        uint256[] memory indexs = new uint256[](batchSize);
        string[] memory addresses = new string[](batchSize);
        for (uint16 i; i < batchSize; ++i) {
            taskIds[i] = taskSubmitter.submitTask(TASK_CONTEXT);
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            accounts[i] = 10001;
            chains[i] = IAccountManager.Chain.BTC;
            indexs[i] = 0;
            addresses[i] = "depositAddress";
        }
        bytes memory callData = abi.encodeWithSelector(
            IAccountManager.registerNewAddress_Batch.selector,
            users,
            accounts,
            chains,
            indexs,
            addresses
        );
        bytes memory encodedData = abi.encodePacked(
            votingManager.tssNonce(),
            amProxy,
            callData,
            taskIds
        );
        bytes memory signature = _generateSignature(encodedData, tssKey);
        for (uint16 i; i < batchSize; ++i) {
            assertFalse(taskManager.isTaskCompleted(taskIds[i]));
        }
        votingManager.verifyAndCall_Batch(amProxy, callData, taskIds, signature);
        for (uint16 i; i < batchSize; ++i) {
            assertEq(
                accountManager.addressRecord(
                    abi.encodePacked(users[i], accounts[i], chains[i], indexs[i])
                ),
                addresses[i]
            );
        }

        // fail: different input parameters length
        users = new address[](batchSize + 1);
        users[users.length - 1] = msgSender;
        callData = abi.encodeWithSelector(
            IAccountManager.registerNewAddress_Batch.selector,
            users,
            accounts,
            chains,
            indexs,
            addresses
        );
        encodedData = abi.encodePacked(votingManager.tssNonce(), amProxy, callData, taskIds);
        signature = _generateSignature(encodedData, tssKey);
        vm.expectRevert(IAccountManager.InvalidInput.selector);
        votingManager.verifyAndCall_Batch(amProxy, callData, taskIds, signature);

        vm.stopPrank();
    }

    function testFuzz_CreateFuzz(
        address _user,
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
            accountManager.registerNewAddress(_user, _account, chain, _index, _address);
            // check mappings|reverseMapping
            assertEq(
                accountManager.addressRecord(abi.encodePacked(_user, _account, chain, _index)),
                _address
            );
            assertEq(accountManager.userMapping(_address, chain), _user);
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(IAccountManager.InvalidAccountNumber.selector, _account)
            );
            accountManager.registerNewAddress(_user, _account, chain, _index, _address);
            vm.stopPrank();
        }
    }
}
