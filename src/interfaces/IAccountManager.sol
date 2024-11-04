// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

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

    error InvalidAddress();
    error InvalidAccountNumber(uint);
    error RegisteredAccount(address, address);

    function addressRecord(bytes calldata _input) external view returns (address);
    function userMapping(address _addr, Chain _chain) external view returns (address);
    function getAddressRecord(
        address _user,
        uint256 _account,
        Chain _chain,
        uint256 _index
    ) external view returns (address);

    function registerNewAddress(
        address _user,
        uint _account,
        Chain _chain,
        uint _index,
        address _address
    ) external;
}
