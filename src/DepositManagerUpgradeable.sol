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
        uint48 chainId,
        bytes calldata txInfo,
        bytes calldata extraInfo
    ) external onlyOwner returns (bytes memory) {
        require(amount > 0, InvalidAmount());
        deposits[targetAddress].push(
            DepositInfo({
                targetAddress: targetAddress,
                amount: amount,
                chainId: chainId,
                txInfo: txInfo,
                extraInfo: extraInfo
            })
        );

        // mint inscription
        nip20Contract.mint(targetAddress, amount);
        emit DepositRecorded(targetAddress, amount, chainId, txInfo, extraInfo);
        return abi.encodePacked(true, uint8(1), targetAddress, amount, chainId, txInfo, extraInfo);
    }

    function record_Batch(
        address[] calldata targetAddresses,
        uint256[] calldata amounts,
        uint48[] calldata chainIds,
        bytes[] calldata txInfos,
        bytes[] calldata extraInfos
    ) external onlyOwner returns (bytes[] memory) {
        require(
            targetAddresses.length == amounts.length &&
                chainIds.length == amounts.length &&
                chainIds.length == txInfos.length &&
                extraInfos.length == txInfos.length,
            "invalid inputs"
        );
        DepositInfo memory newDeposit;
        bytes[] memory results = new bytes[](amounts.length);
        for (uint16 i; i < amounts.length; ++i) {
            require(amounts[i] > 0, InvalidAmount());
            newDeposit = DepositInfo({
                targetAddress: targetAddresses[i],
                amount: amounts[i],
                chainId: chainIds[i],
                txInfo: txInfos[i],
                extraInfo: extraInfos[i]
            });
            deposits[targetAddresses[i]].push(newDeposit);

            // mint inscription
            nip20Contract.mint(targetAddresses[i], amounts[i]);
            emit DepositRecorded(
                targetAddresses[i],
                amounts[i],
                chainIds[i],
                txInfos[i],
                extraInfos[i]
            );
            results[i] = abi.encodePacked(
                true,
                uint8(1),
                targetAddresses[i],
                amounts[i],
                chainIds[i],
                txInfos[i],
                extraInfos[i]
            );
        }
        return results;
    }

    function recordWithdrawal(
        address targetAddress,
        uint256 amount,
        uint48 chainId,
        bytes calldata txInfo,
        bytes calldata extraInfo
    ) external onlyOwner returns (bytes memory) {
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
        return abi.encodePacked(true, uint8(1), targetAddress, amount, chainId, txInfo, extraInfo);
    }
}
