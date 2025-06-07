pragma solidity ^0.8.0;

import "./BaseTest.sol";

import {IParticipantHandler} from "../src/interfaces/IParticipantHandler.sol";

contract ParticipantTest is BaseTest {
    address public user;

    address public participant1;
    address public participant2;
    address public participantHandlerProxy;
    address public nextSubmitter;

    function setUp() public override {
        super.setUp();
        participant1 = makeAddr("participant1");
        participant2 = makeAddr("participant2");

        // stake for the initial participants
        vm.startPrank(participant1);
        nuvoToken.mint(participant1, 100 ether);
        nuvoToken.approve(address(nuvoLock), MIN_LOCK_AMOUNT);
        nuvoLock.lock(MIN_LOCK_AMOUNT, MIN_LOCK_PERIOD);
        vm.stopPrank();
        vm.startPrank(participant2);
        nuvoToken.mint(participant2, 100 ether);
        nuvoToken.approve(address(nuvoLock), MIN_LOCK_AMOUNT);
        nuvoLock.lock(MIN_LOCK_AMOUNT, MIN_LOCK_PERIOD);
        vm.stopPrank();

        participantHandlerProxy = _deployProxy(
            address(new ParticipantHandlerUpgradeable(address(nuvoLock), address(taskManager))),
            daoContract
        );
        participantHandler = ParticipantHandlerUpgradeable(participantHandlerProxy);
        address[] memory participants = new address[](2);
        participants[0] = msgSender;
        participants[1] = participant1;
        // must have at least 3 participants
        vm.expectRevert(IParticipantHandler.NotEnoughParticipant.selector);
        participantHandler.initialize(daoContract, entryPointProxy, msgSender, participants);
        participants = new address[](3);
        participants[0] = msgSender;
        participants[1] = participant1;
        participants[2] = participant2;
        participantHandler.initialize(daoContract, entryPointProxy, msgSender, participants);
        assertEq(participantHandler.getParticipants().length, 3);

        assert(
            entryPoint.nextSubmitter() == msgSender ||
                entryPoint.nextSubmitter() == participant1 ||
                entryPoint.nextSubmitter() == participant2
        );

        // assign handlers
        handlers.push(participantHandlerProxy);
        taskManager.initialize(daoContract, entryPointProxy, handlers);
    }

    function test_AddParticipant() public {
        vm.prank(msgSender);
        // create an eligible user
        address newParticipant = makeAddr("newParticipant");
        // fail: did not stake
        vm.expectRevert(
            abi.encodeWithSelector(IParticipantHandler.NotEligible.selector, newParticipant)
        );
        participantHandler.submitAddParticipantTask(newParticipant, bytes32(uint256(0)));

        vm.startPrank(newParticipant);
        nuvoToken.mint(newParticipant, 100 ether);
        nuvoToken.approve(address(nuvoLock), MIN_LOCK_AMOUNT);
        nuvoLock.lock(MIN_LOCK_AMOUNT, MIN_LOCK_PERIOD);
        vm.stopPrank();

        // fail: only owner
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)")),
                thisAddr,
                ENTRYPOINT_ROLE
            )
        );
        participantHandler.addParticipant(newParticipant, bytes32(uint256(0)));

        // successfully add new user
        vm.prank(msgSender);
        participantHandler.submitAddParticipantTask(newParticipant, bytes32(uint256(1)));
        taskOpts[0].initialCalldata = abi.encodeWithSelector(
            participantHandler.addParticipant.selector,
            newParticipant,
            bytes32(uint256(1))
        );
        signature = _generateOptSignature(taskOpts, tssKey);
        vm.prank(entryPoint.nextSubmitter());
        vm.expectEmit(true, true, true, true);
        emit IParticipantHandler.ParticipantAdded(newParticipant);
        entryPoint.verifyAndCall(taskOpts, signature);

        // fail: adding the same user again
        vm.prank(msgSender);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipantHandler.AlreadyParticipant.selector, newParticipant)
        );
        participantHandler.submitAddParticipantTask(newParticipant, bytes32(uint256(2)));
    }

    function test_RemoveParticipant() public {
        // add one valid partcipant
        address newParticipant = makeAddr("newParticipant");
        _addParticipant(newParticipant);

        // remove the added user
        vm.prank(msgSender);
        participantHandler.submitRemoveParticipantTask(newParticipant, bytes32(uint256(0)));
        taskOpts[0].taskId = taskManager.nextTaskId() - 1;
        taskOpts[0].initialCalldata = abi.encodeWithSelector(
            participantHandler.removeParticipant.selector,
            newParticipant,
            bytes32(uint256(0))
        );
        signature = _generateOptSignature(taskOpts, tssKey);
        vm.prank(entryPoint.nextSubmitter());
        vm.expectEmit(true, true, true, true);
        emit IParticipantHandler.ParticipantRemoved(newParticipant);
        entryPoint.verifyAndCall(taskOpts, signature);
    }

    function test_RemoveParticipantRevert() public {
        vm.prank(msgSender);
        // fail: cannot remove user when there is only 3 participant left
        vm.expectRevert(IParticipantHandler.NotEnoughParticipant.selector);
        participantHandler.submitRemoveParticipantTask(msgSender, bytes32(uint256(0)));

        // add one valid partcipant
        address newParticipant = makeAddr("newParticipant");
        _addParticipant(newParticipant);

        // fail: remove a non-participant user
        address randomAddress = makeAddr("randomAddress");
        vm.prank(msgSender);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipantHandler.NotParticipant.selector, randomAddress)
        );
        participantHandler.submitRemoveParticipantTask(randomAddress, bytes32(uint256(1)));
    }

    function test_massAddAndRemove() public {
        uint64 initialTaskId = taskManager.nextTaskId();
        uint8 initNumOfParticipant = 3;
        uint8 batchSize = 20;
        TaskOperation[] memory taskOperations = new TaskOperation[](batchSize);
        address[] memory newParticipants = new address[](batchSize);
        for (uint8 i; i < batchSize; ++i) {
            // add a participant
            newParticipants[i] = makeAddr(UintToString.uint256ToString(i));
            _lockFor(newParticipants[i]);
            participantHandler.submitAddParticipantTask(newParticipants[i], bytes32(uint256(i)));
            taskOperations[i] = TaskOperation(
                i + initialTaskId,
                State.Completed,
                abi.encodeWithSelector(
                    participantHandler.addParticipant.selector,
                    newParticipants[i],
                    bytes32(uint256(i))
                ),
                ""
            );
        }
        signature = _generateOptSignature(taskOperations, tssKey);
        nextSubmitter = entryPoint.nextSubmitter();
        vm.prank(nextSubmitter);
        entryPoint.verifyAndCall(taskOperations, signature);
        initNumOfParticipant = initNumOfParticipant + batchSize;
        assertEq(participantHandler.getParticipants().length, initNumOfParticipant);
        vm.startPrank(msgSender);
        for (uint8 i; i < batchSize; ++i) {
            // remove a participant
            participantHandler.submitRemoveParticipantTask(newParticipants[i], bytes32(uint256(i)));
            taskOperations[i] = TaskOperation(
                i + initialTaskId + batchSize,
                State.Completed,
                abi.encodeWithSelector(
                    participantHandler.removeParticipant.selector,
                    newParticipants[i],
                    bytes32(uint256(i))
                ),
                ""
            );
        }
        vm.stopPrank();
        signature = _generateOptSignature(taskOperations, tssKey);
        nextSubmitter = entryPoint.nextSubmitter();
        vm.prank(nextSubmitter);
        entryPoint.verifyAndCall(taskOperations, signature);
        assertEq(participantHandler.getParticipants().length, 3);
    }

    function test_resetParticipants() public {
        vm.startPrank(msgSender);
        address[] memory newParticipants = new address[](2);
        newParticipants[0] = address(1);
        newParticipants[1] = participant1;
        vm.expectRevert(IParticipantHandler.NotEnoughParticipant.selector);
        participantHandler.submitResetParticipantsTask(newParticipants, bytes32(uint256(0)));

        newParticipants = new address[](3);
        newParticipants[0] = address(1);
        newParticipants[1] = participant1;
        newParticipants[2] = participant2;
        participantHandler.submitResetParticipantsTask(newParticipants, bytes32(uint256(0)));
        vm.stopPrank();

        taskOpts[0].taskId = taskManager.nextTaskId() - 1;
        taskOpts[0].initialCalldata = abi.encodeWithSelector(
            participantHandler.resetParticipants.selector,
            newParticipants,
            bytes32(uint256(0))
        );
        signature = _generateOptSignature(taskOpts, tssKey);
        vm.prank(entryPoint.nextSubmitter());
        entryPoint.verifyAndCall(taskOpts, signature);

        vm.prank(entryPointProxy);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipantHandler.NotEligible.selector, address(1))
        );
        participantHandler.resetParticipants(newParticipants, bytes32(uint256(0)));

        newParticipants[0] = address(msgSender);
        vm.prank(msgSender);
        participantHandler.submitResetParticipantsTask(newParticipants, bytes32(uint256(1)));
        taskOpts[0].taskId = taskManager.nextTaskId() - 1;
        taskOpts[0].initialCalldata = abi.encodeWithSelector(
            participantHandler.resetParticipants.selector,
            newParticipants,
            bytes32(uint256(1))
        );
        signature = _generateOptSignature(taskOpts, tssKey);
        vm.expectEmit(true, true, true, true);
        emit IParticipantHandler.ParticipantsReset(newParticipants);
        vm.prank(entryPoint.nextSubmitter());
        entryPoint.verifyAndCall(taskOpts, signature);
    }

    function _addParticipant(address _newParticipant) internal returns (address) {
        _lockFor(_newParticipant);
        // add new user through entryPoint
        participantHandler.submitAddParticipantTask(_newParticipant, bytes32(uint256(999)));
        taskOpts[0].initialCalldata = abi.encodeWithSelector(
            participantHandler.addParticipant.selector,
            _newParticipant,
            bytes32(uint256(999))
        );
        signature = _generateOptSignature(taskOpts, tssKey);
        vm.prank(entryPoint.nextSubmitter());
        entryPoint.verifyAndCall(taskOpts, signature);
        return _newParticipant;
    }

    // create an eligible user
    function _lockFor(address _newParticipant) internal {
        vm.startPrank(_newParticipant);
        nuvoToken.mint(_newParticipant, 100 ether);
        nuvoToken.approve(address(nuvoLock), MIN_LOCK_AMOUNT);
        nuvoLock.lock(MIN_LOCK_AMOUNT, MIN_LOCK_PERIOD);
        vm.stopPrank();
        vm.prank(msgSender);
    }
}
