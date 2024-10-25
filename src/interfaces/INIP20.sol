// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INIP20 {
    event NIP20TokenEvent_mint(
        address sender,
        address recipient,
        bytes32 ticker,
        uint256 id,
        uint256 amount
    );
    event NIP20TokenEvent_transfer(
        address sender,
        address recipient,
        bytes32 ticker,
        bytes32 txhash
    );
    event NIP20TokenEvent_burn(address sender, bytes32 ticker, bytes32 txhash);
    event NIP20TokenEvent_transferFromPreviousOwner(
        address sender,
        address recipient,
        address prevOwner,
        bytes32 ticker,
        bytes32 txhash
    );

    event NIP721TokenEvent_mint(address sender, address recipient, bytes32 ticker, string message);

    function mint(address _recipient, uint256 _amount) external;
}
