// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IProxy {
    event Upgraded(address indexed implementation);

    function upgrade(address _newImplementation) external;
}
