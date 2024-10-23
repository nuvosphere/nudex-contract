// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IAccountManager.sol";

contract AccountManagerUpgradeable is IAccountManager, OwnableUpgradeable {
    mapping(bytes => address) public addressRecord;
    mapping(address depositAddress => mapping(Chain => address user)) public userMapping;

    // _owner: Voting Manager contract
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    // register new deposit address for user
    function registerNewAddress(
        address _user,
        uint _account,
        Chain _chain,
        uint _index,
        address _address
    ) external onlyOwner {
        require(
            addressRecord[abi.encodePacked(_user, _account, _chain, _index)] == address(0),
            "already registered"
        );
        require(_account > 10000, "invalid account");
        addressRecord[abi.encodePacked(_user, _account, _chain, _index)] = _address;
        userMapping[_address][_chain] = _user;
        emit AddressRegistered(_user, _account, _chain, _index, _address);
    }
}
