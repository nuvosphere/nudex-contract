// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IAccountHandler} from "../interfaces/IAccountHandler.sol";
import {ITaskManager, State} from "../interfaces/ITaskManager.sol";

contract AccountHandlerUpgradeable is IAccountHandler, AccessControlUpgradeable {
    bytes32 public constant SUBMITTER_ROLE = keccak256("SUBMITTER_ROLE");
    ITaskManager public immutable taskManager;

    mapping(bytes => bytes32) public addressRecord;
    mapping(bytes32 depositAddress => mapping(AddressCategory => uint256 account))
        public userMapping;

    constructor(address _taskManager) {
        taskManager = ITaskManager(_taskManager);
    }

    // _owner: EntryPoint contract
    function initialize(address _owner, address _submitter) public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(SUBMITTER_ROLE, _submitter);
    }

    /**
     * @dev Get registered address record.
     * @param _account Account number, must be greater than 10000.
     * @param _chain The chain type of the address.
     * @param _index The index of adress.
     */
    function getAddressRecord(
        uint256 _account,
        AddressCategory _chain,
        uint256 _index
    ) external view returns (bytes32) {
        return addressRecord[abi.encodePacked(_account, _chain, _index)];
    }

    function submitRegisterTask(
        uint256 _account,
        AddressCategory _chain,
        uint256 _index,
        bytes32 _address
    ) external onlyRole(SUBMITTER_ROLE) returns (uint64) {
        require(_address != 0x00, InvalidAddress());
        require(_account > 10000, InvalidAccountNumber(_account));
        require(
            addressRecord[abi.encodePacked(_account, _chain, _index)] == 0x00,
            RegisteredAccount(_account, addressRecord[abi.encodePacked(_account, _chain, _index)])
        );
        return
            taskManager.submitTask(
                msg.sender,
                abi.encodeWithSelector(
                    this.registerNewAddress.selector,
                    _account,
                    _chain,
                    _index,
                    _address
                )
            );
    }

    /**
     * @dev Register new deposit address for user account.
     * @param _account Account number, must be greater than 10000.
     * @param _chain The chain type of the address.
     * @param _index The index of adress.
     * @param _address The registering address.
     */
    function registerNewAddress(
        uint256 _account,
        AddressCategory _chain,
        uint256 _index,
        bytes32 _address
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bytes memory) {
        addressRecord[abi.encodePacked(_account, _chain, _index)] = _address;
        userMapping[_address][_chain] = _account;
        emit AddressRegistered(_account, _chain, _index, _address);
        return abi.encodePacked(uint8(1), State.Completed, _account, _chain, _index, _address);
    }
}
