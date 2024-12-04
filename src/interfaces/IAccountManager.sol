// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IAccountManager {
    enum Chain {
        BTC,
        EVM,
        SOL, // Solana
        SUI,
        EVM_TSS
    }

    event AddressRegistered(
        uint account,
        Chain indexed chain,
        uint index,
        string indexed newAddress
    );

    error InvalidAddress();
    error InvalidAccountNumber(uint);
    error InvalidInput();
    error RegisteredAccount(uint256, string);

    function addressRecord(bytes calldata _input) external view returns (string calldata);
    function userMapping(string calldata _addr, Chain _chain) external view returns (uint256);
    function getAddressRecord(
        uint256 _account,
        Chain _chain,
        uint256 _index
    ) external view returns (string memory);

    function registerNewAddress(
        uint _account,
        Chain _chain,
        uint _index,
        string calldata _address
    ) external returns (bytes memory);
}
