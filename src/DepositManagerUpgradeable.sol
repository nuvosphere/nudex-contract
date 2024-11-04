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
        address targetAddress,
        uint256 amount,
        uint256 chainId,
        bytes calldata txInfo,
        bytes calldata extraInfo
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

        // mint inscription
        nip20Contract.mint(targetAddress, amount);
        emit DepositRecorded(targetAddress, amount, chainId, txInfo, extraInfo);
    }

    function recordWithdrawal(
        address targetAddress,
        uint256 amount,
        uint256 chainId,
        bytes calldata txInfo,
        bytes calldata extraInfo
    ) external onlyOwner {
        require(amount > 0, InvalidAmount());
        WithdrawalInfo memory newWithdrawal = WithdrawalInfo({
            targetAddress: targetAddress,
            amount: amount,
            chainId: chainId,
            txInfo: txInfo,
            extraInfo: extraInfo
        });
        withdrawals[targetAddress].push(newWithdrawal);

        // TODO: burn inscription?
        emit WithdrawalRecorded(targetAddress, amount, chainId, txInfo, extraInfo);
    }
}
