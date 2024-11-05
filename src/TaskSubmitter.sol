// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract TaskSubmitterUpgradeable is OwnableUpgradeable {
    // _owner: votingManager
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }
}
