// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IDepositManager} from "./interfaces/IDepositManager.sol";

contract DepositManagerUpgradeable is IDepositManager, OwnableUpgradeable {
    mapping(address => DepositInfo[]) public deposits;

    // _owner: Voting Manager contract
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    function recordDeposit(
        address targetAddress,
        uint256 amount,
        uint256 chainId,
        bytes memory txInfo,
        bytes memory extraInfo
    ) external onlyOwner {
        require(amount > 0, InvalidAmount());
        DepositInfo memory newDeposit = DepositInfo({
            targetAddress: targetAddress,
            amount: amount,
            chainId: chainId,
            txInfo: txInfo,
            extraInfo: extraInfo
        });

        deposits[targetAddress].push(newDeposit);

        emit DepositRecorded(targetAddress, amount, chainId, txInfo, extraInfo);
    }

    function getDeposits(address targetAddress) external view returns (DepositInfo[] memory) {
        return deposits[targetAddress];
    }

    function getDeposit(
        address targetAddress,
        uint256 index
    ) external view returns (DepositInfo memory) {
        return deposits[targetAddress][index];
    }
}
