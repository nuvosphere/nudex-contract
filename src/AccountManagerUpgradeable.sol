// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IAccountManager} from "./interfaces/IAccountManager.sol";

contract AccountManagerUpgradeable is IAccountManager, OwnableUpgradeable {
    mapping(bytes => string) public addressRecord;
    mapping(string depositAddress => mapping(Chain => address user)) public userMapping;

    // _owner: Voting Manager contract
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    function getAddressRecord(
        address _user,
        uint256 _account,
        Chain _chain,
        uint256 _index
    ) external view returns (string memory) {
        return addressRecord[abi.encodePacked(_user, _account, _chain, _index)];
    }

    // register new deposit address for user
    function registerNewAddress(
        address _user,
        uint256 _account,
        Chain _chain,
        uint256 _index,
        string calldata _address
    ) external onlyOwner {
        require(bytes(_address).length != 0, InvalidAddress());
        require(_account > 10000, InvalidAccountNumber(_account));
        require(
            bytes(addressRecord[abi.encodePacked(_user, _account, _chain, _index)]).length == 0,
            RegisteredAccount(
                _user,
                addressRecord[abi.encodePacked(_user, _account, _chain, _index)]
            )
        );
        addressRecord[abi.encodePacked(_user, _account, _chain, _index)] = _address;
        userMapping[_address][_chain] = _user;
        emit AddressRegistered(_user, _account, _chain, _index, _address);
    }
}
