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
        string indexed newAddress
    );

    error InvalidAddress();
    error InvalidAccountNumber(uint);
    error InvalidInput();
    error RegisteredAccount(address, string);

    function addressRecord(bytes calldata _input) external view returns (string calldata);
    function userMapping(string calldata _addr, Chain _chain) external view returns (address);
    function getAddressRecord(
        address _user,
        uint256 _account,
        Chain _chain,
        uint256 _index
    ) external view returns (string memory);

    function registerNewAddress(
        address _user,
        uint _account,
        Chain _chain,
        uint _index,
        string calldata _address
    ) external returns (bytes memory);

    function registerNewAddress_Batch(
        address[] calldata _users,
        uint256[] calldata _accounts,
        Chain[] calldata _chains,
        uint256[] calldata _indexs,
        string[] calldata _addresses
    ) external returns (bytes[] memory);
}
