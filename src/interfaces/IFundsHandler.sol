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
        string depositAddress,
        bytes32 indexed ticker,
        bytes32 indexed chainId,
        uint256 amount
    );
    event WithdrawalRecorded(
        string depositAddress,
        bytes32 indexed ticker,
        bytes32 indexed chainId,
        uint256 amount
    );

    error InvalidAmount();
    error InvalidInput();
    error InvalidAddress();
    error Paused();

    function recordDeposit(
        address _userAddress,
        string calldata _depositAddress,
        bytes32 _ticker,
        bytes32 _chainId,
        uint256 _amount
    ) external returns (bytes memory);

    function recordWithdrawal(
        string calldata _depositAddress,
        bytes32 _ticker,
        bytes32 _chainId,
        uint256 _amount
    ) external returns (bytes memory);

    function getDeposits(
        string calldata depositAddress
    ) external view returns (DepositInfo[] memory);
    function getWithdrawals(
        string calldata depositAddress
    ) external view returns (WithdrawalInfo[] memory);
}
