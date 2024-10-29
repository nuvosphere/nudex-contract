// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAccountManager {
    enum Chain {
        BTC,
        EVM,
        EVM_TSS
    }

    event AddressRegistered(
        address indexed user,
        uint account,
        Chain indexed chainId,
        uint index,
        address indexed newAddress
    );

    error RegisteredAccount();
    error InvalidAccountNumber();
    error InvalidAddress();

    function addressRecord(bytes calldata _input) external view returns (address);
    function userMapping(address _addr, Chain _chain) external view returns (address);

    // register new deposit address for user
    function registerNewAddress(
        address _user,
        uint _account,
        Chain _chain,
        uint _index,
        address _address
    ) external;
}
