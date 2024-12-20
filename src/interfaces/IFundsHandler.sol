// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IFundsHandler {
    struct DepositInfo {
        string depositAddress;
        bytes32 ticker;
        bytes32 chainId;
        uint256 amount;
    }

    struct WithdrawalInfo {
        string depositAddress;
        bytes32 ticker;
        bytes32 chainId;
        uint256 amount;
    }

    event NewPauseState(bytes32 condition, bool newState);
    event DepositRecorded(
        string indexed depositAddress,
        bytes32 indexed ticker,
        bytes32 indexed chainId,
        uint256 amount
    );
    event WithdrawalRecorded(
        string indexed depositAddress,
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
        uint256 _amount,
        string calldata _depositAddress
    ) external returns (bytes memory);

    function recordWithdrawal(
        address _userAddress,
        bytes32 _ticker,
        bytes32 _chainId,
        uint256 _amount,
        uint256 _btcAmount,
        string calldata _depositAddress
    ) external returns (bytes memory);

    function getDeposits(
        string calldata depositAddress
    ) external view returns (DepositInfo[] memory);
    function getWithdrawals(
        string calldata depositAddress
    ) external view returns (WithdrawalInfo[] memory);
}
