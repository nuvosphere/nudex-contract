// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAccountManager} from "./interfaces/IAccountManager.sol";

contract AccountManagerUpgradeable is IAccountManager, OwnableUpgradeable {
    mapping(bytes => address) public addressRecord;
    mapping(address depositAddress => mapping(Chain => address user)) public userMapping;

    // _owner: Voting Manager contract
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    function getAddressRecord(
        address _user,
        uint256 _account,
        Chain _chain,
        uint256 _index
    ) external view returns (address) {
        return addressRecord[abi.encodePacked(_user, _account, _chain, _index)];
    }

    // register new deposit address for user
    function registerNewAddress(
        address _user,
        uint256 _account,
        Chain _chain,
        uint256 _index,
        address _address
    ) external onlyOwner {
        require(_address != address(0), InvalidAddress());
        require(_account > 10000, InvalidAccountNumber());
        require(
            addressRecord[abi.encodePacked(_user, _account, _chain, _index)] == address(0),
            RegisteredAccount()
        );
        addressRecord[abi.encodePacked(_user, _account, _chain, _index)] = _address;
        userMapping[_address][_chain] = _user;
        emit AddressRegistered(_user, _account, _chain, _index, _address);
    }
}
