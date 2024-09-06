// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract AccountManager is OwnableUpgradeable {

    event AddressRegistered(address indexed user, uint account, chain indexed chainId, uint index, address indexed newAddress);
    event AddressUnregistered(address indexed user, uint account, chain indexed chainId, uint index);

    enum chain 
    { 
      BTC, 
      EVM, 
      EVM_TSS
    } 
  
    // user address => account => chain => index => registered address
    mapping(address => mapping(uint => mapping(chain => mapping(uint => address)))) public addressRecord;

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    // register new deposit address for user
    function registerNewAddress(address _user, uint _account, chain _chain, uint _index, address _address) external onlyOwner {
        require(addressRecord[_user][_account][_chain][_index] == address(0), "already registered");
        require(_account > 10000);
        addressRecord[_user][_account][_chain][_index] = _address;
        emit AddressRegistered(_user, _account, _chain, _index, _address);
    }

    function unregisterAddress(address _user, uint _account, chain _chain, uint _index) external onlyOwner {
        addressRecord[_user][_account][_chain][_index] = address(0);
        emit AddressUnregistered(_user, _account, _chain, _index);
    }

}