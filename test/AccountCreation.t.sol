pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {AccountManagerUpgradeable} from "../src/AccountManagerUpgradeable.sol";
import {IAccountManager} from "../src/interfaces/IAccountManager.sol";
import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";

contract AccountCreation is Test {
    using MessageHashUtils for bytes32;

    address public daoContract;
    address public owner;
    uint256 public privKey;
    AccountManagerUpgradeable public accountManager;
    VotingManagerUpgradeable public votingManager;

    function setUp() public {
        (owner, privKey) = makeAddrAndKey("owner");
        owner = address(this);
        daoContract = makeAddr("dao");

        // deploy votingManager
        votingManager = new VotingManagerUpgradeable();

        // deploy accountManager
        address proxy = Upgrades.deployTransparentProxy(
            "AccountManagerUpgradeable.sol",
            daoContract,
            abi.encodeCall(AccountManagerUpgradeable.initialize, address(votingManager))
        );
        accountManager = AccountManagerUpgradeable(proxy);
        assertEq(accountManager.owner(), address(votingManager));

        votingManager.initialize(
            address(accountManager),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            owner
        );
    }

    function test_Create() public {
        console.log(address(votingManager), accountManager.owner());
        address addr = makeAddr("new_account");

        // success
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
        votingManager.registerAccount(owner, 10001, IAccountManager.Chain.BTC, 0, addr, signature);
    }

    function test_CreateFail() public {
        address addr = makeAddr("new_account");

        // fail: not the owner
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), owner)
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
