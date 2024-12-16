// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IFundsHandler {
    struct DepositInfo {
        address targetAddress;
        bytes32 ticker;
        uint256 chainId;
        uint256 amount;
    }

    struct WithdrawalInfo {
        address targetAddress;
        bytes32 ticker;
        uint256 chainId;
        uint256 amount;
    }

    event DepositRecorded(
        address indexed targetAddress,
        uint256 indexed amount,
        uint256 indexed chainId
    );
    event WithdrawalRecorded(
        address indexed targetAddress,
        uint256 indexed amount,
        uint256 indexed chainId
    );

    error InvalidAmount();
    error InvalidInput();
    error InvalidAddress();

    function recordDeposit(
        address _targetAddress,
        bytes32 _ticker,
        uint256 _chainId,
        uint256 _amount
    ) external returns (bytes memory);

    function recordWithdrawal(
        address _targetAddress,
        bytes32 _ticker,
        uint256 _chainId,
        uint256 _amount
    ) external returns (bytes memory);

    function getDeposits(address targetAddress) external view returns (DepositInfo[] memory);
    function getWithdrawals(address targetAddress) external view returns (WithdrawalInfo[] memory);
}
