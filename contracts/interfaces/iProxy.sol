// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface iProxy {
    event Upgraded(address indexed implementation);

    function upgrade(address _newImplementation) external;
}
