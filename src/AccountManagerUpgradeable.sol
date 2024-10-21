// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IAccountManager.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract AccountManagerUpgradeable is IAccountManager, OwnableUpgradeable {
    mapping(bytes => address) public addressRecord;
    // encode(user address, account, chain, index) => registered address
    mapping(address user => mapping(Chain => address depositAddress)) public userMapping;

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
        require(_account > 10000);
        addressRecord[abi.encodePacked(_user, _account, _chain, _index)] = _address;
        userMapping[_address][_chain] = _user;
        emit AddressRegistered(_user, _account, _chain, _index, _address);
    }
}
