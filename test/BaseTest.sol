pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {ParticipantManagerUpgradeable} from "../src/ParticipantManagerUpgradeable.sol";
import {NuvoLockUpgradeable} from "../src/NuvoLockUpgradeable.sol";
import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";

import {MockNuvoToken} from "../src/mocks/MockNuvoToken.sol";

contract BaseTest is Test {
    using MessageHashUtils for bytes32;

    uint256 public constant MIN_LOCK_AMOUNT = 1 ether;
    uint256 public constant MIN_LOCK_PERIOD = 1 weeks;

    MockNuvoToken public nuvoToken;

    ParticipantManagerUpgradeable public participantManager;
    NuvoLockUpgradeable public nuvoLock;
    VotingManagerUpgradeable public votingManager;

    address public vmProxy;

    address public daoContract;
    address public thisAddr;
    address public msgSender;
    address[] public participants;
    address public tssSigner;
    uint256 public tssKey;

    function setUp() public virtual {
        msgSender = makeAddr("msgSender");
        (tssSigner, tssKey) = makeAddrAndKey("tss");
        daoContract = makeAddr("dao");
        thisAddr = address(this);
        participants.push(msgSender);
        participants.push(msgSender);
        participants.push(msgSender);
        // console.log("Addresses: ", address(this), msgSender);

        // deploy mock nuvoToken
        // vm.prank(msgSender);
        nuvoToken = new MockNuvoToken();
        nuvoToken.mint(msgSender, 100 ether);

        // deploy votingManager proxy
        vmProxy = deployProxy(address(new VotingManagerUpgradeable()), daoContract);

        // deploy NuvoLockUpgradeable
        address nuvoLockProxy = deployProxy(address(new NuvoLockUpgradeable()), daoContract);
        nuvoLock = NuvoLockUpgradeable(nuvoLockProxy);
        nuvoLock.initialize(
            address(nuvoToken),
            msgSender,
            vmProxy,
            MIN_LOCK_AMOUNT,
            MIN_LOCK_PERIOD
        );
        assertEq(nuvoLock.owner(), vmProxy);

        // deploy ParticipantManagerUpgradeable
        address participantManagerProxy = deployProxy(
            address(new ParticipantManagerUpgradeable()),
            daoContract
        );
        participantManager = ParticipantManagerUpgradeable(participantManagerProxy);
        participantManager.initialize(address(nuvoLock), vmProxy, participants);
        assertEq(participantManager.owner(), vmProxy);

        // setups
        vm.startPrank(msgSender);
        nuvoToken.approve(nuvoLockProxy, MIN_LOCK_AMOUNT);
        nuvoLock.lock(MIN_LOCK_AMOUNT, MIN_LOCK_PERIOD);
        vm.stopPrank();
    }

    function deployProxy(address _logic, address _admin) internal returns (address) {
        return address(new TransparentUpgradeableProxy(_logic, _admin, ""));
    }

    function generateSignature(
        bytes memory _encodedParams,
        uint256 _privateKey
    ) internal view returns (bytes memory) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                votingManager.tssNonce(),
                uint256ToString(_encodedParams.length),
                _encodedParams
            )
        ).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function uint256ToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
