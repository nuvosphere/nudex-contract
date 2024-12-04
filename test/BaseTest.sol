pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {NuvoLockUpgradeable} from "../src/NuvoLockUpgradeable.sol";
import {ParticipantManagerUpgradeable} from "../src/ParticipantManagerUpgradeable.sol";
import {TaskManagerUpgradeable} from "../src/TaskManagerUpgradeable.sol";
import {TaskSubmitter} from "../src/TaskSubmitter.sol";
import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";

import {IVotingManager} from "../src/interfaces/IVotingManager.sol";
import {Operation} from "../src/interfaces/IVotingManager.sol";
import {State} from "../src/interfaces/ITaskManager.sol";
import {UintToString} from "../src/libs/UintToString.sol";

import {MockNuvoToken} from "../src/mocks/MockNuvoToken.sol";

contract BaseTest is Test {
    using MessageHashUtils for bytes32;

    uint256 public constant MIN_LOCK_AMOUNT = 1 ether;
    uint32 public constant MIN_LOCK_PERIOD = 1 weeks;

    MockNuvoToken public nuvoToken;

    NuvoLockUpgradeable public nuvoLock;
    ParticipantManagerUpgradeable public participantManager;
    TaskManagerUpgradeable public taskManager;
    TaskSubmitter public taskSubmitter;
    VotingManagerUpgradeable public votingManager;

    address public vmProxy;

    address public daoContract;
    address public thisAddr;
    address public msgSender;
    address public tssSigner;
    uint256 public tssKey;

    function setUp() public virtual {
        msgSender = makeAddr("msgSender");
        (tssSigner, tssKey) = makeAddrAndKey("tss");
        daoContract = makeAddr("dao");
        thisAddr = address(this);
        // console.log("Addresses: ", address(this), msgSender);

        // deploy mock nuvoToken
        // vm.prank(msgSender);
        nuvoToken = new MockNuvoToken();
        nuvoToken.mint(msgSender, 100 ether);

        // deploy votingManager proxy
        vmProxy = _deployProxy(address(new VotingManagerUpgradeable()), daoContract);

        // deploy NuvoLockUpgradeable
        address nuvoLockProxy = _deployProxy(address(new NuvoLockUpgradeable()), daoContract);
        nuvoLock = NuvoLockUpgradeable(nuvoLockProxy);
        nuvoLock.initialize(
            address(nuvoToken),
            msgSender,
            vmProxy,
            MIN_LOCK_AMOUNT,
            MIN_LOCK_PERIOD
        );
        assertEq(nuvoLock.owner(), vmProxy);

        // deploy taskManager
        address tmProxy = _deployProxy(address(new TaskManagerUpgradeable()), daoContract);
        taskSubmitter = new TaskSubmitter(tmProxy);
        taskManager = TaskManagerUpgradeable(tmProxy);
        taskManager.initialize(address(taskSubmitter), vmProxy);
        assertEq(taskManager.owner(), vmProxy);

        // deploy ParticipantManagerUpgradeable
        address participantManagerProxy = _deployProxy(
            address(new ParticipantManagerUpgradeable()),
            daoContract
        );
        participantManager = ParticipantManagerUpgradeable(participantManagerProxy);
        address[] memory participants = new address[](3);
        participants[0] = msgSender;
        participants[1] = msgSender;
        participants[2] = msgSender;
        participantManager.initialize(address(nuvoLock), vmProxy, participants);
        assertEq(participantManager.owner(), vmProxy);

        // setups
        vm.startPrank(msgSender);
        nuvoToken.approve(nuvoLockProxy, MIN_LOCK_AMOUNT);
        nuvoLock.lock(MIN_LOCK_AMOUNT, MIN_LOCK_PERIOD);
        vm.stopPrank();
    }

    function _deployProxy(address _logic, address _admin) internal returns (address) {
        return address(new TransparentUpgradeableProxy(_logic, _admin, ""));
    }

    function _generateSignature(
        Operation[] memory _opt,
        uint256 _privateKey
    ) internal view returns (bytes memory) {
        bytes memory encodedData = abi.encode(votingManager.tssNonce(), _opt);
        bytes32 digest = keccak256(encodedData).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _generateSignature(
        bytes memory _encodedData,
        uint256 _privateKey
    ) internal pure returns (bytes memory) {
        bytes32 digest = keccak256(_encodedData).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
