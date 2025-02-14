// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

enum AddressCategory {
    BTC,
    EVM,
    SOL,
    SUI,
    EVM_TSS
}

struct AccountRegistrationTaskParam {
    address userAddr;
    uint32 account;
    AddressCategory addressCategory;
    uint32 index;
}

interface IAccountHandler {
    // events
    event AddressRegistered(
        address userAddr,
        uint256 indexed account,
        AddressCategory indexed chain,
        uint256 indexed index,
        string newAddress
    );

    // errors
    error InvalidAddress();
    error InvalidUserAddress();
    error InvalidAccountNumber(uint32);
    error InvalidInput();
    error MismatchedAccount(address);
    error RegisteredAccount(uint256, string);

    function addressRecord(bytes32 _input) external view returns (string memory);
    function userAddresses(uint32 _accountNumber) external view returns (address);

    function userMapping(
        string calldata _addr,
        AddressCategory _chain
    ) external view returns (address);

    function getAddressRecord(
        uint32 _accountNumber,
        AddressCategory _chain,
        uint32 _index
    ) external view returns (string memory);

    function registerNewAddress(
        address _userAddr,
        uint32 _accountNumber,
        AddressCategory _chain,
        uint32 _index,
        string calldata _address
    ) external;
}
