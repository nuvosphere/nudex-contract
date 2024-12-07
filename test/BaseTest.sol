pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {NuvoLockUpgradeable} from "../src/NuvoLockUpgradeable.sol";
import {ParticipantHandlerUpgradeable} from "../src/handlers/ParticipantHandlerUpgradeable.sol";
import {TaskManagerUpgradeable} from "../src/tasks/TaskManagerUpgradeable.sol";
import {TaskSubmitterUpgradeable} from "../src/tasks/TaskSubmitterUpgradeable.sol";
import {EntryPointUpgradeable} from "../src/EntryPointUpgradeable.sol";

import {IEntryPoint} from "../src/interfaces/IEntryPoint.sol";
import {Operation} from "../src/interfaces/IEntryPoint.sol";
import {State} from "../src/interfaces/ITaskManager.sol";
import {UintToString} from "../src/libs/UintToString.sol";

import {MockNuvoToken} from "../src/mocks/MockNuvoToken.sol";

contract BaseTest is Test {
    using MessageHashUtils for bytes32;

    uint256 public constant MIN_LOCK_AMOUNT = 1 ether;
    uint32 public constant MIN_LOCK_PERIOD = 1 weeks;

    MockNuvoToken public nuvoToken;

    NuvoLockUpgradeable public nuvoLock;
    ParticipantHandlerUpgradeable public participantHandler;
    TaskManagerUpgradeable public taskManager;
    TaskSubmitterUpgradeable public taskSubmitter;
    EntryPointUpgradeable public entryPoint;

    address public vmProxy;

    address public daoContract;
    address public thisAddr;
    address public msgSender;
    address public tssSigner;
    uint256 public tssKey;

    bytes public tempBytes = "Context";

    function setUp() public virtual {
        msgSender = makeAddr("msgSender");
        (tssSigner, tssKey) = makeAddrAndKey("tss");
        daoContract = makeAddr("dao");
        thisAddr = address(this);

        // deploy mock nuvoToken
        nuvoToken = new MockNuvoToken();
        nuvoToken.mint(msgSender, 100 ether);

        // deploy entryPoint proxy
        vmProxy = _deployProxy(address(new EntryPointUpgradeable()), daoContract);

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

        // deploy taskManager and taskSubmitter
        address tmProxy = _deployProxy(address(new TaskManagerUpgradeable()), daoContract);
        address tsProxy = _deployProxy(
            address(new TaskSubmitterUpgradeable(address(tmProxy))),
            daoContract
        );
        taskSubmitter = TaskSubmitterUpgradeable(tsProxy);
        taskSubmitter.initialize(vmProxy);
        // add msgSender to whitelist
        vm.prank(vmProxy);
        taskSubmitter.setWhitelist(uint8(0), msgSender);
        taskManager = TaskManagerUpgradeable(tmProxy);
        taskManager.initialize(address(taskSubmitter), vmProxy);
        assertEq(taskManager.owner(), vmProxy);

        // deploy ParticipantHandlerUpgradeable
        address participantHandlerProxy = _deployProxy(
            address(new ParticipantHandlerUpgradeable()),
            daoContract
        );
        participantHandler = ParticipantHandlerUpgradeable(participantHandlerProxy);
        address[] memory participants = new address[](3);
        participants[0] = msgSender;
        participants[1] = msgSender;
        participants[2] = msgSender;
        participantHandler.initialize(address(nuvoLock), vmProxy, participants);
        assertEq(participantHandler.owner(), vmProxy);

        // setups
        vm.startPrank(msgSender);
        nuvoToken.approve(nuvoLockProxy, MIN_LOCK_AMOUNT);
        nuvoLock.lock(MIN_LOCK_AMOUNT, MIN_LOCK_PERIOD);
        vm.stopPrank();
    }

    function _deployProxy(address _logic, address _admin) internal returns (address) {
        return address(new TransparentUpgradeableProxy(_logic, _admin, ""));
    }

    // generate signature for operations
    function _generateOptSignature(
        Operation[] memory _opt,
        uint256 _privateKey
    ) internal view returns (bytes memory) {
        bytes memory encodedData = abi.encode(entryPoint.tssNonce(), block.chainid, _opt);
        bytes32 digest = keccak256(encodedData).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    // generate signature for encoded data
    function _generateDataSignature(
        bytes memory _encodedData,
        uint256 _privateKey
    ) internal pure returns (bytes memory) {
        bytes32 digest = keccak256(_encodedData).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _generateTaskContext() internal returns (bytes memory) {
        tempBytes = abi.encodePacked(uint8(0), keccak256(tempBytes));
        return tempBytes;
    }
}
