pragma solidity ^0.8.0;

import "./BaseTest.sol";

import {AccountHandlerUpgradeable} from "../src/handlers/AccountHandlerUpgradeable.sol";
import {IAccountHandler} from "../src/interfaces/IAccountHandler.sol";
import {ITaskManager, State} from "../src/interfaces/ITaskManager.sol";

contract AccountCreationTest is BaseTest {
    uint256 constant DEFAULT_ACCOUNT = 10001;

    string public depositAddress;

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
        accountHandler.initialize(daoContract, vmProxy, msgSender);
        assertTrue(accountHandler.hasRole(ENTRYPOINT_ROLE, vmProxy));

        // assign handlers
        handlers.push(amProxy);
        taskManager.initialize(daoContract, vmProxy, handlers);
    }

    function test_Create() public {
        vm.startPrank(msgSender);
        // submit task
        taskIds[0] = accountHandler.submitRegisterTask(
            DEFAULT_ACCOUNT,
            IAccountHandler.AddressCategory.BTC,
            0,
            depositAddress
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
        assertEq(uint8(taskManager.getTaskState(taskIds[0])), uint8(State.Completed));

        // fail: already registered
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccountHandler.RegisteredAccount.selector,
                DEFAULT_ACCOUNT,
                depositAddress
            )
        );
        taskIds[0] = accountHandler.submitRegisterTask(
            DEFAULT_ACCOUNT,
            IAccountHandler.AddressCategory.BTC,
            0,
            depositAddress
        );
        vm.stopPrank();
    }

    function test_TaskRevert() public {
        vm.startPrank(msgSender);
        // fail case: deposit address as address zero
        vm.expectRevert(IAccountHandler.InvalidAddress.selector);
        accountHandler.submitRegisterTask(
            DEFAULT_ACCOUNT,
            IAccountHandler.AddressCategory.BTC,
            0,
            ""
        );

        // fail case: account number less than 10000
        uint256 invalidAccountNum = uint256(9999);
        vm.expectRevert(
            abi.encodeWithSelector(IAccountHandler.InvalidAccountNumber.selector, invalidAccountNum)
        );
        accountHandler.submitRegisterTask(
            invalidAccountNum,
            IAccountHandler.AddressCategory.BTC,
            0,
            depositAddress
        );
        vm.stopPrank();
    }

    function testFuzz_SubmitTaskFuzz(
        uint256 _account,
        uint8 _chain,
        uint256 _index,
        string calldata _address
    ) public {
        vm.assume(_account < 10000000);
        vm.assume(_chain < 3);
        vm.assume(bytes(_address).length > 0);
        IAccountHandler.AddressCategory chain = IAccountHandler.AddressCategory(_chain);
        vm.startPrank(msgSender);
        if (_account > 10000) {
            accountHandler.submitRegisterTask(_account, chain, _index, _address);
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(IAccountHandler.InvalidAccountNumber.selector, _account)
            );
            accountHandler.submitRegisterTask(_account, chain, _index, _address);
        }
        vm.stopPrank();
    }
}
