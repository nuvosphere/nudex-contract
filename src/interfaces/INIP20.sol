// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface INIP20 {
    event NIP20TokenEvent_mintb(address recipient, bytes32 ticker, uint256 amount);
    event NIP20TokenEvent_burnb(address from, bytes32 ticker, uint256 amount);
}
