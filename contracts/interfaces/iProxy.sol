// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProxy {
    event Upgraded(address indexed implementation);

    function upgrade(address _newImplementation) external;
}
