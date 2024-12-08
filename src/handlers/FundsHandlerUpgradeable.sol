// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IFundsHandler} from "../interfaces/IFundsHandler.sol";

contract FundsHandlerUpgradeable is IFundsHandler, OwnableUpgradeable {
    mapping(address => DepositInfo[]) public deposits;
    mapping(address => WithdrawalInfo[]) public withdrawals;

    // _owner: EntryPoint contract
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    /**
     * @dev Get all deposit records of user.
     */
    function getDeposits(address targetAddress) external view returns (DepositInfo[] memory) {
        require(targetAddress != address(0), InvalidAddress());
        return deposits[targetAddress];
    }

    /**
     * @dev Get n-th deposit record of user.
     */
    function getDeposit(
        address targetAddress,
        uint256 index
    ) external view returns (DepositInfo memory) {
        require(targetAddress != address(0), InvalidAddress());
        return deposits[targetAddress][index];
    }

    /**
     * @dev Get all withdraw records of user.
     */
    function getWithdrawals(address targetAddress) external view returns (WithdrawalInfo[] memory) {
        return withdrawals[targetAddress];
    }

    /**
     * @dev Get n-th withdraw record of user.
     */
    function getWithdrawal(
        address targetAddress,
        uint256 index
    ) external view returns (WithdrawalInfo memory) {
        require(targetAddress != address(0), InvalidAddress());
        return withdrawals[targetAddress][index];
    }

    /**
     * @dev Record deposit info.
     */
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
        return abi.encodePacked(uint8(1), _targetAddress, _amount, _chainId, _txInfo, _extraInfo);
    }

    /**
     * @dev Record withdraw info.
     */
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
        return abi.encodePacked(uint8(1), _targetAddress, _amount, _chainId, _txInfo, _extraInfo);
    }
}
