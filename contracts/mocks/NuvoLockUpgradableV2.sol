// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../NuvoLockUpgradeable.sol";

contract NuvoLockUpgradeableV2 is NuvoLockUpgradeable {
    function newFunctionality() public pure returns (string memory) {
        return "New functionality";
    }
}
