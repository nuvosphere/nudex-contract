// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Proxy {
    address public implementation;

    event Upgraded(address indexed implementation);

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function upgrade(address _newImplementation) external {
        require(msg.sender == address(this), "Can only be upgraded through DAO proposal");
        implementation = _newImplementation;
        emit Upgraded(_newImplementation);
    }

    fallback() external payable {
        address impl = implementation;
        require(impl != address(0), "Implementation contract not set");

        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), impl, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }
}
