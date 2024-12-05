// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IDepositManager} from "../interfaces/IDepositManager.sol";

contract DepositManagerUpgradeable is IDepositManager, OwnableUpgradeable {
    mapping(address => DepositInfo[]) public deposits;
    mapping(address => WithdrawalInfo[]) public withdrawals;

    // _owner: Voting Manager contract
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    function getDeposits(address targetAddress) external view returns (DepositInfo[] memory) {
        require(targetAddress != address(0), InvalidAddress());
        return deposits[targetAddress];
    }

    function getDeposit(
        address targetAddress,
        uint256 index
    ) external view returns (DepositInfo memory) {
        require(targetAddress != address(0), InvalidAddress());
        return deposits[targetAddress][index];
    }

    function getWithdrawals(address targetAddress) external view returns (WithdrawalInfo[] memory) {
        return withdrawals[targetAddress];
    }

    function getWithdrawal(
        address targetAddress,
        uint256 index
    ) external view returns (WithdrawalInfo memory) {
        require(targetAddress != address(0), InvalidAddress());
        return withdrawals[targetAddress][index];
    }

    function recordDeposit(
        address _targetAddress,
        uint256 _amount,
        uint256 _chainId,
        bytes calldata _txInfo,
        bytes calldata _extraInfo
    ) external onlyOwner returns (bytes memory) {
        require(_amount > 0, InvalidAmount());
        require(_targetAddress != address(0), InvalidAddress());
        deposits[_targetAddress].push(
            DepositInfo({
                targetAddress: _targetAddress,
                chainId: _chainId,
                amount: _amount,
                txInfo: _txInfo,
                extraInfo: _extraInfo
            })
        );

        // TODO: mint inscription
        emit DepositRecorded(_targetAddress, _amount, _chainId, _txInfo, _extraInfo);
        return
            abi.encodePacked(
                true,
                uint8(1),
                _targetAddress,
                _amount,
                _chainId,
                _txInfo,
                _extraInfo
            );
    }

    function recordWithdrawal(
        address _targetAddress,
        uint256 _amount,
        uint256 _chainId,
        bytes calldata _txInfo,
        bytes calldata _extraInfo
    ) external onlyOwner returns (bytes memory) {
        require(_amount > 0, InvalidAmount());
        require(_targetAddress != address(0), InvalidAddress());
        withdrawals[_targetAddress].push(
            WithdrawalInfo({
                targetAddress: _targetAddress,
                amount: _amount,
                chainId: _chainId,
                txInfo: _txInfo,
                extraInfo: _extraInfo
            })
        );

        // TODO: burn inscription?
        emit WithdrawalRecorded(_targetAddress, _amount, _chainId, _txInfo, _extraInfo);
        return
            abi.encodePacked(
                true,
                uint8(1),
                _targetAddress,
                _amount,
                _chainId,
                _txInfo,
                _extraInfo
            );
    }
}
