// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MockLogic1 {
    uint256 public constant v = 1;

    function show() external pure returns (string memory) {
        return "MockLogic1";
    }
}

contract MockLogic2 {
    uint256 public constant v = 2;

    function show() external pure returns (string memory) {
        return "MockLogic2";
    }

    function func2() external pure returns (string memory) {
        return "Only logic 2";
    }
}

contract MockSelfUpgrade {
    uint256 public constant v = 3;

    function upgrade(address _newImp, bytes calldata _data) external {
        ITransparentUpgradeableProxy(address(this)).upgradeToAndCall(_newImp, _data);
    }
}
