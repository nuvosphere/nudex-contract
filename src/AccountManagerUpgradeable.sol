// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAccountManager} from "./interfaces/IAccountManager.sol";

contract AccountManagerUpgradeable is IAccountManager, OwnableUpgradeable {
    mapping(bytes => string) public addressRecord;
    mapping(string depositAddress => mapping(Chain => uint256 account)) public userMapping;

    // _owner: Voting Manager contract
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    function getAddressRecord(
        uint256 _account,
        Chain _chain,
        uint256 _index
    ) external view returns (string memory) {
        return addressRecord[abi.encodePacked(_account, _chain, _index)];
    }

    // register new deposit address for user account
    function registerNewAddress(
        uint256 _account,
        Chain _chain,
        uint256 _index,
        string calldata _address
    ) external onlyOwner returns (bytes memory) {
        require(bytes(_address).length != 0, InvalidAddress());
        require(_account > 10000, InvalidAccountNumber(_account));
        require(
            bytes(addressRecord[abi.encodePacked(_account, _chain, _index)]).length == 0,
            RegisteredAccount(_account, addressRecord[abi.encodePacked(_account, _chain, _index)])
        );
        addressRecord[abi.encodePacked(_account, _chain, _index)] = _address;
        userMapping[_address][_chain] = _account;
        emit AddressRegistered(_account, _chain, _index, _address);
        return abi.encodePacked(true, uint8(1), _account, _chain, _index);
    }
}
