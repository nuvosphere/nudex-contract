// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IDepositManager} from "./interfaces/IDepositManager.sol";
import {INIP20} from "./interfaces/INIP20.sol";

contract DepositManagerUpgradeable is IDepositManager, OwnableUpgradeable {
    INIP20 public nip20Contract;

    mapping(address => DepositInfo[]) public deposits;
    mapping(address => WithdrawalInfo[]) public withdrawals;

    // _owner: Voting Manager contract
    function initialize(address _owner, address _nip20Contract) public initializer {
        __Ownable_init(_owner);
        nip20Contract = INIP20(_nip20Contract);
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

    function getWithdrawals(address targetAddress) external view returns (WithdrawalInfo[] memory) {
        return withdrawals[targetAddress];
    }

    function getWithdrawal(
        address targetAddress,
        uint256 index
    ) external view returns (WithdrawalInfo memory) {
        return withdrawals[targetAddress][index];
    }

    function recordDeposit(
        address _targetAddress,
        uint256 _amount,
        uint64 _chainId,
        bytes calldata _txInfo,
        bytes calldata _extraInfo
    ) external onlyOwner returns (bytes memory) {
        return _recordDeposit(_targetAddress, _amount, _chainId, _txInfo, _extraInfo);
    }

    function recordDeposit_Batch(
        address[] calldata _targetAddresses,
        uint256[] calldata _amounts,
        uint64[] calldata _chainIds,
        bytes[] calldata _txInfos,
        bytes[] calldata _extraInfos
    ) external onlyOwner returns (bytes[] memory) {
        require(
            _targetAddresses.length == _amounts.length &&
                _chainIds.length == _amounts.length &&
                _chainIds.length == _txInfos.length &&
                _extraInfos.length == _txInfos.length,
            InvalidInput()
        );
        bytes[] memory results = new bytes[](_amounts.length);
        for (uint16 i; i < _amounts.length; ++i) {
            results[i] = _recordDeposit(
                _targetAddresses[i],
                _amounts[i],
                _chainIds[i],
                _txInfos[i],
                _extraInfos[i]
            );
        }
        return results;
    }

    function recordWithdrawal(
        address _targetAddress,
        uint256 _amount,
        uint64 _chainId,
        bytes calldata _txInfo,
        bytes calldata _extraInfo
    ) external onlyOwner returns (bytes memory) {
        return _recordWithdrawal(_targetAddress, _amount, _chainId, _txInfo, _extraInfo);
    }

    function recordWithdrawal_Batch(
        address[] calldata _targetAddresses,
        uint256[] calldata _amounts,
        uint64[] calldata _chainIds,
        bytes[] calldata _txInfos,
        bytes[] calldata _extraInfos
    ) external onlyOwner returns (bytes[] memory) {
        require(
            _targetAddresses.length == _amounts.length &&
                _chainIds.length == _amounts.length &&
                _chainIds.length == _txInfos.length &&
                _extraInfos.length == _txInfos.length,
            InvalidInput()
        );
        bytes[] memory results = new bytes[](_amounts.length);
        for (uint16 i; i < _amounts.length; ++i) {
            results[i] = _recordWithdrawal(
                _targetAddresses[i],
                _amounts[i],
                _chainIds[i],
                _txInfos[i],
                _extraInfos[i]
            );
        }
        return results;
    }

    function _recordDeposit(
        address _targetAddress,
        uint256 _amount,
        uint64 _chainId,
        bytes calldata _txInfo,
        bytes calldata _extraInfo
    ) internal returns (bytes memory) {
        require(_amount > 0, InvalidAmount());
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

    function _recordWithdrawal(
        address _targetAddress,
        uint256 _amount,
        uint64 _chainId,
        bytes calldata _txInfo,
        bytes calldata _extraInfo
    ) internal returns (bytes memory) {
        require(_amount > 0, InvalidAmount());
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
