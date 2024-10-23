pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract BaseTest is Test {
    using MessageHashUtils for bytes32;

    address public daoContract;
    address public thisAddr;
    address public owner;
    uint256 public privKey;

    function setUp() public virtual {
        (owner, privKey) = makeAddrAndKey("owner");
        daoContract = makeAddr("dao");
        thisAddr = address(this);
        console.log("Addresses: ", address(this), owner);
    }

    function generateSignature(
        bytes memory _encodedParams,
        uint256 _privateKey
    ) internal view returns (bytes memory) {
        bytes32 digest = keccak256(
            abi.encodePacked(uint256ToString(_encodedParams.length), _encodedParams)
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
