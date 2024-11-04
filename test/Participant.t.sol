pragma solidity ^0.8.0;

import {BaseTest, console} from "./BaseTest.sol";

import {ParticipantManagerUpgradeable} from "../src/ParticipantManagerUpgradeable.sol";
import {IParticipantManager} from "../src/interfaces/IParticipantManager.sol";
import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";

contract Participant is BaseTest {
    address public user;

    address public participant1;
    address public participant2;
    address public participantManagerProxy;

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

        participantManagerProxy = deployProxy(
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
            tssSigner,
            address(0), // accountManager
            address(0), // assetManager
            address(0), // depositManager
            participantManagerProxy, // participantManager
            address(0), // nudeOperation
            address(nuvoLock) // nuvoLock
        );
        assert(
            votingManager.nextSubmitter() == msgSender ||
                votingManager.nextSubmitter() == participant1 ||
                votingManager.nextSubmitter() == participant2
        );
    }

    function test_AddParticipant() public {
        // create an eligible user
        address newParticipant = makeAddr("newParticipant");
        // fail: did not stake
        bytes memory callData = abi.encodeWithSelector(
            IParticipantManager.addParticipant.selector,
            newParticipant
        );
        bytes memory signature = generateSignature(callData, tssKey);
        vm.prank(votingManager.nextSubmitter());
        vm.expectRevert(IParticipantManager.NotEligible.selector);
        votingManager.verifyAndCall(participantManagerProxy, callData, signature);

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
        callData = abi.encodeWithSelector(
            IParticipantManager.addParticipant.selector,
            newParticipant
        );
        signature = generateSignature(callData, tssKey);
        vm.prank(votingManager.nextSubmitter());
        vm.expectEmit(true, true, true, true);
        emit IParticipantManager.ParticipantAdded(newParticipant);
        votingManager.verifyAndCall(participantManagerProxy, callData, signature);

        // fail: adding the same user again
        signature = generateSignature(callData, tssKey);
        vm.prank(votingManager.nextSubmitter());
        vm.expectRevert(IParticipantManager.AlreadyParticipant.selector);
        votingManager.verifyAndCall(participantManagerProxy, callData, signature);
    }

    function test_RemoveParticipant() public {
        // add one valid partcipant
        address newParticipant = makeAddr("newParticipant");
        _addParticipant(newParticipant);

        // remove the added user
        bytes memory callData = abi.encodeWithSelector(
            IParticipantManager.removeParticipant.selector,
            newParticipant
        );
        bytes memory signature = generateSignature(callData, tssKey);
        vm.prank(votingManager.nextSubmitter());
        vm.expectEmit(true, true, true, true);
        emit IParticipantManager.ParticipantRemoved(newParticipant);
        votingManager.verifyAndCall(participantManagerProxy, callData, signature);
    }

    function test_RemoveParticipantRevert() public {
        // fail: cannot remove user when there is only 3 participant left
        bytes memory callData = abi.encodeWithSelector(
            IParticipantManager.removeParticipant.selector,
            msgSender
        );
        bytes memory signature = generateSignature(callData, tssKey);
        vm.prank(votingManager.nextSubmitter());
        vm.expectRevert(IParticipantManager.NotEnoughParticipant.selector);
        votingManager.verifyAndCall(participantManagerProxy, callData, signature);

        // add one valid partcipant
        address newParticipant = makeAddr("newParticipant");
        _addParticipant(newParticipant);

        // fail: remove a non-participant user
        callData = abi.encodeWithSelector(IParticipantManager.removeParticipant.selector, thisAddr);
        signature = generateSignature(callData, tssKey);
        vm.prank(votingManager.nextSubmitter());
        vm.expectRevert(IParticipantManager.NotParticipant.selector);
        votingManager.verifyAndCall(participantManagerProxy, callData, signature);
    }

    function test_massAddAndRemove() public {
        uint8 initNumOfParticipant = 3;
        for (uint8 i; i < 20; ++i) {
            _addParticipant(makeAddr(uint256ToString(i)));
            assertEq(participantManager.getParticipants().length, initNumOfParticipant + i + 1);
        }
        assertEq(participantManager.getParticipants().length, 23);
        initNumOfParticipant = 23;
        address submitter = votingManager.nextSubmitter();
        for (uint8 i; i < 20; ++i) {
            // removing a random participant
            bytes memory callData = abi.encodeWithSelector(
                IParticipantManager.removeParticipant.selector,
                participantManager.getRandomParticipant(submitter)
            );
            bytes memory signature = generateSignature(callData, tssKey);
            vm.prank(submitter);
            votingManager.verifyAndCall(participantManagerProxy, callData, signature);
            submitter = votingManager.nextSubmitter();
            assertEq(participantManager.getParticipants().length, initNumOfParticipant - i - 1);
        }
        assertEq(participantManager.getParticipants().length, 3);
    }

    function _addParticipant(address _newParticipant) internal {
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
        bytes memory signature = generateSignature(callData, tssKey);
        vm.prank(votingManager.nextSubmitter());
        votingManager.verifyAndCall(participantManagerProxy, callData, signature);
    }
}
