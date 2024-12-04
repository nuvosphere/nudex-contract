pragma solidity ^0.8.0;

import "./BaseTest.sol";

import {IParticipantManager} from "../src/interfaces/IParticipantManager.sol";

contract Participant is BaseTest {
    address public user;

    address public participant1;
    address public participant2;
    address public participantManagerProxy;
    address public nextSubmitter;

    bytes public constant TASK_CONTEXT = "--- encoded participant task context ---";

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

        participantManagerProxy = _deployProxy(
            address(new ParticipantManagerUpgradeable()),
            daoContract
        );
        participantManager = ParticipantManagerUpgradeable(participantManagerProxy);
        address[] memory participants = new address[](2);
        participants[0] = msgSender;
        participants[1] = participant1;
        // must have at least 3 participants
        vm.expectRevert(IParticipantManager.NotEnoughParticipant.selector);
        participantManager.initialize(address(nuvoLock), vmProxy, participants);
        participants = new address[](3);
        participants[0] = msgSender;
        participants[1] = participant1;
        participants[2] = participant2;
        participantManager.initialize(address(nuvoLock), vmProxy, participants);
        assertEq(participantManager.getParticipants().length, 3);

        votingManager = VotingManagerUpgradeable(vmProxy);
        votingManager.initialize(
            tssSigner, // tssSigner
            participantManagerProxy, // participantManager
            address(taskManager), // taskManager
            address(nuvoLock) // nuvoLock
        );
        assert(
            votingManager.nextSubmitter() == msgSender ||
                votingManager.nextSubmitter() == participant1 ||
                votingManager.nextSubmitter() == participant2
        );
    }

    function test_AddParticipant() public {
        uint64 taskId = taskSubmitter.submitTask(TASK_CONTEXT);
        // create an eligible user
        address newParticipant = makeAddr("newParticipant");
        // fail: did not stake
        bytes memory callData = abi.encodeWithSelector(
            IParticipantManager.addParticipant.selector,
            newParticipant
        );
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(participantManagerProxy, State.Completed, taskId, callData);
        bytes memory signature = _generateSignature(opts, tssKey);
        nextSubmitter = votingManager.nextSubmitter();
        vm.expectEmit(true, true, true, true);
        emit IVotingManager.OperationFailed(
            abi.encodeWithSelector(IParticipantManager.NotEligible.selector, newParticipant)
        );
        vm.prank(nextSubmitter);
        votingManager.verifyAndCall(opts, signature);

        vm.startPrank(newParticipant);
        nuvoToken.mint(newParticipant, 100 ether);
        nuvoToken.approve(address(nuvoLock), MIN_LOCK_AMOUNT);
        nuvoLock.lock(MIN_LOCK_AMOUNT, MIN_LOCK_PERIOD);
        vm.stopPrank();

        // fail: only owner
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("OwnableUnauthorizedAccount(address)")),
                thisAddr
            )
        );
        participantManager.addParticipant(newParticipant);

        // successfully add new user
        taskId = taskSubmitter.submitTask(TASK_CONTEXT);
        callData = abi.encodeWithSelector(
            IParticipantManager.addParticipant.selector,
            newParticipant
        );
        opts[0] = Operation(participantManagerProxy, State.Completed, taskId, callData);
        signature = _generateSignature(opts, tssKey);
        vm.prank(votingManager.nextSubmitter());
        vm.expectEmit(true, true, true, true);
        emit IParticipantManager.ParticipantAdded(newParticipant);
        votingManager.verifyAndCall(opts, signature);

        // fail: adding the same user again
        taskId = taskSubmitter.submitTask(TASK_CONTEXT);
        opts[0] = Operation(participantManagerProxy, State.Completed, taskId, callData);
        signature = _generateSignature(opts, tssKey);
        nextSubmitter = votingManager.nextSubmitter();
        vm.prank(nextSubmitter);
        vm.expectEmit(true, true, true, true);
        emit IVotingManager.OperationFailed(
            abi.encodeWithSelector(IParticipantManager.AlreadyParticipant.selector, newParticipant)
        );
        votingManager.verifyAndCall(opts, signature);
    }

    function test_RemoveParticipant() public {
        // add one valid partcipant
        address newParticipant = makeAddr("newParticipant");
        _addParticipant(newParticipant);

        // remove the added user
        uint64 taskId = taskSubmitter.submitTask(TASK_CONTEXT);
        bytes memory callData = abi.encodeWithSelector(
            IParticipantManager.removeParticipant.selector,
            newParticipant
        );
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(participantManagerProxy, State.Completed, taskId, callData);
        bytes memory signature = _generateSignature(opts, tssKey);
        vm.prank(votingManager.nextSubmitter());
        vm.expectEmit(true, true, true, true);
        emit IParticipantManager.ParticipantRemoved(newParticipant);
        votingManager.verifyAndCall(opts, signature);
    }

    function test_RemoveParticipantRevert() public {
        uint64 taskId = taskSubmitter.submitTask(TASK_CONTEXT);
        // fail: cannot remove user when there is only 3 participant left
        bytes memory callData = abi.encodeWithSelector(
            IParticipantManager.removeParticipant.selector,
            msgSender
        );
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(participantManagerProxy, State.Completed, taskId, callData);
        bytes memory signature = _generateSignature(opts, tssKey);
        vm.prank(votingManager.nextSubmitter());
        vm.expectEmit(true, true, true, true);
        emit IVotingManager.OperationFailed(
            abi.encodeWithSelector(IParticipantManager.NotEnoughParticipant.selector)
        );
        votingManager.verifyAndCall(opts, signature);

        // add one valid partcipant
        address newParticipant = makeAddr("newParticipant");
        _addParticipant(newParticipant);

        // fail: remove a non-participant user
        taskId = taskSubmitter.submitTask(TASK_CONTEXT);
        callData = abi.encodeWithSelector(IParticipantManager.removeParticipant.selector, thisAddr);
        opts[0] = Operation(participantManagerProxy, State.Completed, taskId, callData);
        signature = _generateSignature(opts, tssKey);
        nextSubmitter = votingManager.nextSubmitter();
        vm.expectEmit(true, true, true, true);
        emit IVotingManager.OperationFailed(
            abi.encodeWithSelector(IParticipantManager.NotParticipant.selector, thisAddr)
        );
        vm.prank(nextSubmitter);
        votingManager.verifyAndCall(opts, signature);
    }

    function test_massAddAndRemove() public {
        uint8 initNumOfParticipant = 3;
        address[] memory newParticipants = new address[](20);
        for (uint8 i; i < 20; ++i) {
            newParticipants[i] = _addParticipant(makeAddr(UintToString.uint256ToString(i)));
            assertEq(participantManager.getParticipants().length, initNumOfParticipant + i + 1);
        }
        assertEq(participantManager.getParticipants().length, 23);
        initNumOfParticipant = 23;
        uint64 taskId;
        bytes memory callData;
        Operation[] memory opts = new Operation[](20);
        for (uint8 i; i < 20; ++i) {
            // removing a participant
            taskId = taskSubmitter.submitTask(TASK_CONTEXT);
            callData = abi.encodeWithSelector(
                IParticipantManager.removeParticipant.selector,
                newParticipants[i]
            );
            opts[i] = Operation(participantManagerProxy, State.Completed, taskId, callData);
        }
        bytes memory signature = _generateSignature(opts, tssKey);
        nextSubmitter = votingManager.nextSubmitter();
        vm.prank(nextSubmitter);
        votingManager.verifyAndCall(opts, signature);
        assertEq(participantManager.getParticipants().length, 3);
    }

    function _addParticipant(address _newParticipant) internal returns (address) {
        uint64 taskId = taskSubmitter.submitTask(TASK_CONTEXT);
        // create an eligible user
        nuvoToken.mint(_newParticipant, 100 ether);
        vm.startPrank(_newParticipant);
        nuvoToken.approve(address(nuvoLock), MIN_LOCK_AMOUNT);
        nuvoLock.lock(MIN_LOCK_AMOUNT, MIN_LOCK_PERIOD);
        vm.stopPrank();

        // add new user through votingManager
        bytes memory callData = abi.encodeWithSelector(
            IParticipantManager.addParticipant.selector,
            _newParticipant
        );
        Operation[] memory opts = new Operation[](1);
        opts[0] = Operation(participantManagerProxy, State.Completed, taskId, callData);
        bytes memory signature = _generateSignature(opts, tssKey);
        vm.prank(votingManager.nextSubmitter());
        votingManager.verifyAndCall(opts, signature);
        return _newParticipant;
    }
}
