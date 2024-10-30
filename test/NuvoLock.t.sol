pragma solidity ^0.8.0;

import {BaseTest, console} from "./BaseTest.sol";

import {NuvoLockUpgradeable} from "../src/NuvoLockUpgradeable.sol";
import {INuvoLock} from "../src/interfaces/INuvoLock.sol";
import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";

import {MockParticipantManager} from "../src/mocks/MockParticipantManager.sol";
import {MockNuvoLockUpgradeable} from "../src/mocks/MockNuvoLockUpgradeable.sol";
import {MockNuvoToken} from "../src/mocks/MockNuvoToken.sol";

contract NuvoLockTest is BaseTest {
    address public user;

    uint256 public constant ONE_WEEK = 1 weeks;

    MockNuvoToken public nuvoToken;
    MockParticipantManager public participantManager;

    NuvoLockUpgradeable public nuvoLock;

    function setUp() public override {
        super.setUp();

        // deploy mock contract
        participantManager = new MockParticipantManager(msgSender);
        vm.prank(msgSender);
        nuvoToken = new MockNuvoToken();

        // deploy NuvoLockUpgradeable
        address nuvoLockProxy = deployProxy(address(new NuvoLockUpgradeable()), daoContract);
        nuvoLock = NuvoLockUpgradeable(nuvoLockProxy);
        nuvoLock.initialize(address(nuvoToken), msgSender, vmProxy, ONE_WEEK);
        assertEq(nuvoLock.owner(), vmProxy);

        // initialize votingManager link to all contracts
        votingManager = VotingManagerUpgradeable(vmProxy);
        votingManager.initialize(
            tssSigner,
            address(0), // accountManager
            address(0), // assetManager
            address(0), // depositManager
            address(participantManager), // participantManager
            address(0), // nudeOperation
            address(nuvoLock) // nuvoLock
        );
    }

    function test_Lock() public {
        // first participant
        uint256 totalAmount = nuvoLock.totalLocked();
        uint256 lockAmount = 1 ether;
        uint256 lastPeriodNumber = nuvoLock.lastPeriodNumber();
        vm.startPrank(msgSender);
        assertEq(nuvoLock.lockedBalanceOf(msgSender), 0);

        nuvoToken.approve(address(nuvoLock), lockAmount);
        vm.expectEmit(true, true, true, true);
        emit INuvoLock.Locked(msgSender, lockAmount, block.timestamp + ONE_WEEK);
        nuvoLock.lock(lockAmount, ONE_WEEK);
        totalAmount += lockAmount;

        assertEq(nuvoToken.balanceOf(address(nuvoLock)), totalAmount);
        assertEq(nuvoLock.totalLocked(), totalAmount);
        assertEq(nuvoLock.participants(0), msgSender);
        INuvoLock.LockInfo memory expectedLockInfo = INuvoLock.LockInfo({
            amount: lockAmount,
            unlockTime: block.timestamp + ONE_WEEK,
            originalLockTime: ONE_WEEK,
            startTime: block.timestamp,
            bonusPoints: 0,
            accumulatedRewards: 0,
            lastClaimedPeriod: lastPeriodNumber,
            demeritPoints: 0
        });
        {
            (
                uint256 amount,
                uint256 unlockTime,
                uint256 originalLockTime,
                uint256 startTime,
                uint256 bonusPoints,
                uint256 accumulatedRewards,
                uint256 lastClaimedPeriod,
                uint256 demeritPoints
            ) = nuvoLock.locks(msgSender);
            assertEq(
                abi.encode(expectedLockInfo),
                abi.encode(
                    amount,
                    unlockTime,
                    originalLockTime,
                    startTime,
                    bonusPoints,
                    accumulatedRewards,
                    lastClaimedPeriod,
                    demeritPoints
                )
            );
        }

        // second participant
        address user2 = makeAddr("user2");
        lockAmount = 2 ether;
        nuvoToken.transfer(user2, lockAmount);
        vm.startPrank(user2);
        nuvoToken.approve(address(nuvoLock), lockAmount);
        vm.expectEmit(true, true, true, true);
        emit INuvoLock.Locked(user2, lockAmount, block.timestamp + ONE_WEEK);
        nuvoLock.lock(lockAmount, ONE_WEEK);
        totalAmount += lockAmount;

        assertEq(nuvoToken.balanceOf(address(nuvoLock)), totalAmount);
        assertEq(nuvoLock.totalLocked(), totalAmount);
        assertEq(nuvoLock.participants(1), user2);
        expectedLockInfo = INuvoLock.LockInfo({
            amount: lockAmount,
            unlockTime: block.timestamp + ONE_WEEK,
            originalLockTime: ONE_WEEK,
            startTime: block.timestamp,
            bonusPoints: 0,
            accumulatedRewards: 0,
            lastClaimedPeriod: lastPeriodNumber,
            demeritPoints: 0
        });
        {
            (
                uint256 amount,
                uint256 unlockTime,
                uint256 originalLockTime,
                uint256 startTime,
                uint256 bonusPoints,
                uint256 accumulatedRewards,
                uint256 lastClaimedPeriod,
                uint256 demeritPoints
            ) = nuvoLock.locks(user2);
            assertEq(
                abi.encode(expectedLockInfo),
                abi.encode(
                    amount,
                    unlockTime,
                    originalLockTime,
                    startTime,
                    bonusPoints,
                    accumulatedRewards,
                    lastClaimedPeriod,
                    demeritPoints
                )
            );
        }
        vm.stopPrank();
    }

    function test_LockRevert() public {
        vm.startPrank(msgSender);
        uint256 lockAmount = 1 ether;
        // fail case: amount = 0
        vm.expectRevert(INuvoLock.InvalidAmount.selector);
        nuvoLock.lock(0, ONE_WEEK);
        // fail case: lock period less than the minLockPeriod
        vm.expectRevert(INuvoLock.TimePeriodBelowMin.selector);
        nuvoLock.lock(lockAmount, ONE_WEEK - 1);
        // fail case: did not approve before lock
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("ERC20InsufficientAllowance(address,uint256,uint256)")),
                address(nuvoLock),
                0,
                lockAmount
            )
        );
        nuvoLock.lock(lockAmount, ONE_WEEK);
        // fail case: insufficient balance
        nuvoToken.transfer(thisAddr, nuvoToken.balanceOf(msgSender));
        nuvoToken.approve(address(nuvoLock), lockAmount);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("ERC20InsufficientBalance(address,uint256,uint256)")),
                msgSender,
                0,
                lockAmount
            )
        );
        nuvoLock.lock(lockAmount, ONE_WEEK);

        // success
        nuvoToken.mint(msgSender, lockAmount);
        nuvoToken.approve(address(nuvoLock), lockAmount);
        nuvoLock.lock(lockAmount, ONE_WEEK);

        // fail case: already locked
        vm.expectRevert(INuvoLock.AlreadyLocked.selector);
        nuvoLock.lock(lockAmount, ONE_WEEK);

        vm.stopPrank();
    }
}
