// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAccountHandler, AddressCategory, AccountRegistrationTaskParam} from "../interfaces/IAccountHandler.sol";
import {HandlerBase} from "./HandlerBase.sol";

contract AccountHandlerUpgradeable is IAccountHandler, HandlerBase {
    mapping(uint32 userAccount => address userAddress) private userAddresses;

    mapping(bytes32 => string) public addressRecord;
    mapping(string depositAddress => mapping(AddressCategory => address account))
        public userMapping;

    constructor(address _taskManager) HandlerBase(_taskManager) {}

    // _owner: EntryPoint contract
    function initialize(
        address _owner,
        address _entryPoint,
        address _submitter
    ) public initializer {
        __HandlerBase_init(_owner, _entryPoint, _submitter);
    }

    /**
     * @dev Get registered address record.
     * @param _accountNumber Account number, must be greater than 10000.
     * @param _addressCategory The address category of the address.
     * @param _index The index of address.
     */
    function getAddressRecord(
        uint32 _accountNumber,
        AddressCategory _addressCategory,
        uint32 _index
    ) external view returns (string memory) {
        return addressRecord[keccak256(abi.encodePacked(_accountNumber, _addressCategory, _index))];
    }

    /**
     * @dev Get user address by account number.
     * @param _accountNumber Account number.
     * @notice Revert if the account number is not registered.
     */
    function getUserAddress(uint32 _accountNumber) external view returns (address) {
        require(userAddresses[_accountNumber] != address(0), "Unregistered account");
        return userAddresses[_accountNumber];
    }

    /**
     * @dev Submit a task to register new deposit address for user account.
     * @param _params The task parameters
     * address userAddr The EVM address of the user.
     * uint32 account The account number, must be greater than 10000.
     * AddressCategory addressCategory The addressCategory type of the address.
     * uint32 index The index of address.
     */
    function submitRegisterTask(
        AccountRegistrationTaskParam[] calldata _params
    ) external onlyRole(SUBMITTER_ROLE) returns (uint64[] memory taskIds) {
        taskIds = new uint64[](_params.length);
        bytes32[] memory dataHashes = new bytes32[](_params.length);
        AccountRegistrationTaskParam memory param;
        for (uint256 i; i < _params.length; i++) {
            param = _params[i];
            require(param.userAddr != address(0), InvalidUserAddress());
            require(param.account > 10000, InvalidAccountNumber(param.account));
            require(
                userAddresses[param.account] == address(0) ||
                    userAddresses[param.account] == param.userAddr,
                MismatchedAccount(userAddresses[param.account])
            );
            require(
                bytes(
                    addressRecord[
                        keccak256(
                            abi.encodePacked(param.account, param.addressCategory, param.index)
                        )
                    ]
                ).length == 0,
                RegisteredAccount(
                    param.account,
                    addressRecord[
                        keccak256(
                            abi.encodePacked(param.account, param.addressCategory, param.index)
                        )
                    ]
                )
            );

            dataHashes[i] = keccak256(
                abi.encodeWithSelector(
                    this.registerNewAddress.selector,
                    param.userAddr,
                    param.account,
                    param.addressCategory,
                    param.index,
                    uint256(160) // offset for address
                )
            );
        }
        taskIds = taskManager.submitTask(dataHashes);
    }

    /**
     * @dev Register new deposit address for user account.
     * @param _userAddr The EVM address of the user.
     * @param _accountNumber Account number, must be greater than 10000.
     * @param _addressCategory The address category of the address.
     * @param _index The index of address.
     * @param _address The registering address.
     */
    function registerNewAddress(
        address _userAddr,
        uint32 _accountNumber,
        AddressCategory _addressCategory,
        uint32 _index,
        string calldata _address
    ) external onlyRole(ENTRYPOINT_ROLE) {
        require(bytes(_address).length > 0, InvalidAddress());
        bytes32 hash = keccak256(abi.encodePacked(_accountNumber, _addressCategory, _index));
        require(
            bytes(addressRecord[hash]).length == 0,
            RegisteredAccount(_accountNumber, addressRecord[hash])
        );

        // check user address => account binding
        if (userAddresses[_accountNumber] == address(0)) {
            userAddresses[_accountNumber] = _userAddr;
        } else {
            require(
                userAddresses[_accountNumber] == _userAddr,
                MismatchedAccount(userAddresses[_accountNumber])
            );
        }

        addressRecord[hash] = _address;
        userMapping[_address][_addressCategory] = _userAddr;
    }
}
