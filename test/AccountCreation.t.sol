pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {Proxy} from "../src/Proxy.sol";
import {AccountManagerUpgradeable} from "../src/AccountManagerUpgradeable.sol";
import {IAccountManager} from "../src/interfaces/IAccountManager.sol";
import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";
import {MockParticipantManager} from "../src/mocks/MockParticipantManager.sol";
import {MockNuvoLockUpgradeable} from "../src/mocks/MockNuvoLockUpgradeable.sol";

contract AccountCreation is Test {
    using MessageHashUtils for bytes32;

    address public daoContract;
    address public owner;
    address public thisAddr;

    uint256 public privKey;
    AccountManagerUpgradeable public accountManager;
    VotingManagerUpgradeable public votingManager;
    MockParticipantManager public participantManager;
    MockNuvoLockUpgradeable public nuvoLock;

    function setUp() public {
        (owner, privKey) = makeAddrAndKey("owner");
        daoContract = makeAddr("dao");
        thisAddr = address(this);
        console.log("Addresses: ", address(this), owner);

        // deploy mock contract
        participantManager = new MockParticipantManager(owner);
        nuvoLock = new MockNuvoLockUpgradeable();

        // deploy votingManager
        address vmLogic = address(new VotingManagerUpgradeable());
        address vmProxy = address(new TransparentUpgradeableProxy(vmLogic, daoContract, ""));

        // deploy accountManager
        address amLogic = address(new AccountManagerUpgradeable());
        address amProxy = address(new TransparentUpgradeableProxy(amLogic, daoContract, ""));
        accountManager = AccountManagerUpgradeable(amProxy);
        accountManager.initialize(vmProxy);
        assertEq(accountManager.owner(), vmProxy);

        votingManager = VotingManagerUpgradeable(vmProxy);
        votingManager.initialize(
            address(accountManager),
            address(0),
            address(0),
            address(participantManager),
            address(0),
            address(nuvoLock),
            owner
        );
        assertEq(address(votingManager.accountManager()), address(accountManager));
    }

    function test_Create() public {
        address addr = makeAddr("new_account");

        bytes memory encodedParams = abi.encodePacked(
            owner,
            uint(10001),
            IAccountManager.Chain.BTC,
            uint(0),
            addr
        );
        bytes32 digest = keccak256(
            abi.encodePacked(uint256ToString(encodedParams.length), encodedParams)
        ).toEthSignedMessageHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.prank(owner);
        votingManager.registerAccount(owner, 10001, IAccountManager.Chain.BTC, 0, addr, signature);
        // check mappings|reverseMapping
        assertEq(
            accountManager.addressRecord(
                abi.encodePacked(owner, uint(10001), IAccountManager.Chain.BTC, uint(0))
            ),
            addr
        );
        assertEq(accountManager.userMapping(addr, IAccountManager.Chain.BTC), owner);
    }

    function test_CreateRevertIfNotTheOwner() public {
        address addr = makeAddr("new_account");
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("OwnableUnauthorizedAccount(address)")),
                thisAddr
            )
        );
        accountManager.registerNewAddress(owner, 10001, IAccountManager.Chain.BTC, 0, addr);
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
