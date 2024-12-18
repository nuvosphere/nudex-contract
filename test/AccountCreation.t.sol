pragma solidity ^0.8.0;

import "./BaseTest.sol";

import {AccountHandlerUpgradeable} from "../src/handlers/AccountHandlerUpgradeable.sol";
import {IAccountHandler} from "../src/interfaces/IAccountHandler.sol";
import {ITaskManager} from "../src/interfaces/ITaskManager.sol";

contract AccountCreationTest is BaseTest {
    uint256 constant DEFAULT_ACCOUNT = 10001;

    uint64[] public taskIds;
    bytes32 public depositAddress;

    AccountHandlerUpgradeable public accountHandler;
    address public amProxy;

    function setUp() public override {
        super.setUp();
        depositAddress = "new_address";

        // deploy accountHandler
        amProxy = _deployProxy(
            address(new AccountHandlerUpgradeable(address(taskManager))),
            daoContract
        );
        accountHandler = AccountHandlerUpgradeable(amProxy);
        accountHandler.initialize(vmProxy, msgSender);
        assertTrue(accountHandler.hasRole(DEFAULT_ADMIN_ROLE, vmProxy));

        address[] memory handlers = new address[](1);
        handlers[0] = amProxy;
        taskManager.initialize(vmProxy, handlers);

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
        taskIds.push(
            accountHandler.submitRegisterTask(
                DEFAULT_ACCOUNT,
                IAccountHandler.AddressCategory.BTC,
                0,
                depositAddress
            )
        );
        bytes memory signature = _generateOptSignature(taskIds, tssKey);
        entryPoint.verifyAndCall(taskIds, signature);

        // check mappings|reverseMapping
        assertEq(
            accountHandler.getAddressRecord(
                DEFAULT_ACCOUNT,
                IAccountHandler.AddressCategory.BTC,
                uint(0)
            ),
            depositAddress
        );
        assertEq(
            accountHandler.addressRecord(
                abi.encodePacked(DEFAULT_ACCOUNT, IAccountHandler.AddressCategory.BTC, uint(0))
            ),
            depositAddress
        );
        assertEq(
            accountHandler.userMapping(depositAddress, IAccountHandler.AddressCategory.BTC),
            DEFAULT_ACCOUNT
        );

        // fail: already registered
        taskIds[0] = accountHandler.submitRegisterTask(
            DEFAULT_ACCOUNT,
            IAccountHandler.AddressCategory.BTC,
            0,
            depositAddress
        );
        signature = _generateOptSignature(taskIds, tssKey);

        vm.expectEmit(true, true, true, true);
        emit IEntryPoint.OperationFailed(
            abi.encodeWithSelector(
                IAccountHandler.RegisteredAccount.selector,
                DEFAULT_ACCOUNT,
                accountHandler.addressRecord(
                    abi.encodePacked(DEFAULT_ACCOUNT, IAccountHandler.AddressCategory.BTC, uint(0))
                )
            )
        );
        entryPoint.verifyAndCall(taskIds, signature);
        vm.stopPrank();
    }

    function test_CreateRevert() public {
        vm.startPrank(msgSender);
        // fail case: deposit address as address zero
        taskIds.push(
            accountHandler.submitRegisterTask(
                DEFAULT_ACCOUNT,
                IAccountHandler.AddressCategory.BTC,
                0,
                0x00
            )
        );
        bytes memory signature = _generateOptSignature(taskIds, tssKey);
        vm.expectEmit(true, true, true, true);
        emit IEntryPoint.OperationFailed(
            abi.encodeWithSelector((IAccountHandler.InvalidAddress.selector))
        );
        entryPoint.verifyAndCall(taskIds, signature);

        // fail case: account number less than 10000
        taskIds[0] = accountHandler.submitRegisterTask(
            uint256(9999),
            IAccountHandler.AddressCategory.BTC,
            0,
            depositAddress
        );
        signature = _generateOptSignature(taskIds, tssKey);
        vm.expectEmit(true, true, true, true);
        emit IEntryPoint.OperationFailed(
            abi.encodeWithSelector(IAccountHandler.InvalidAccountNumber.selector, 9999)
        );
        entryPoint.verifyAndCall(taskIds, signature);
        vm.stopPrank();
    }

    function testFuzz_CreateFuzz(
        uint256 _account,
        uint8 _chain,
        uint256 _index,
        bytes32 _address
    ) public {
        vm.assume(_account < 10000000);
        vm.assume(_chain < 3);
        vm.assume(_address != 0x00);
        IAccountHandler.AddressCategory chain = IAccountHandler.AddressCategory(_chain);
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
