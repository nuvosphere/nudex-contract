// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IFundsHandler {
    struct DepositInfo {
        address userAddress;
        bytes32 ticker;
        bytes32 chainId;
        uint256 amount;
    }

    struct WithdrawalInfo {
        address userAddress;
        bytes32 ticker;
        bytes32 chainId;
        uint256 amount;
    }

    event DepositRecorded(
        address indexed userAddress,
        bytes32 indexed ticker,
        bytes32 indexed chainId,
        uint256 amount
    );
    event WithdrawalRecorded(
        address indexed userAddress,
        bytes32 indexed ticker,
        bytes32 indexed chainId,
        uint256 amount,
        uint256 btcAmount
    );

    error InvalidAmount();
    error InvalidInput();
    error InvalidAddress();
    error Paused();

    function recordDeposit(
        address _userAddress,
        bytes32 _ticker,
        bytes32 _chainId,
        uint256 _amount
    ) external returns (bytes memory);

    function recordWithdrawal(
        address _userAddress,
        bytes32 _ticker,
        bytes32 _chainId,
        uint256 _amount,
        uint256 _btcAmount
    ) external returns (bytes memory);

    function getDeposits(address userAddress) external view returns (DepositInfo[] memory);
    function getWithdrawals(address userAddress) external view returns (WithdrawalInfo[] memory);
}
