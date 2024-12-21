// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface INIP20 {
    event NIP20TokenEvent_mintb(address indexed recipient, bytes32 indexed ticker, uint256 amount);
    event NIP20TokenEvent_burnb(address indexed from, bytes32 indexed ticker, uint256 amount);
}
