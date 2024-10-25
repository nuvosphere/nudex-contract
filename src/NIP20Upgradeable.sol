// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {INIP20} from "./interfaces/INIP20.sol";

contract NIP20Upgradeable is INIP20, OwnableUpgradeable {
    bytes32 public constant TICKER = "nuvoticker";
    uint256 public id;

    // _owner: Deposit Manager contract
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    function mint(address _recipient, uint256 _amount) external onlyOwner {
        emit NIP20TokenEvent_mint(msg.sender, _recipient, TICKER, ++id, _amount);
    }

    function transfer(address _to, bytes32 _txhash) public {
        emit NIP20TokenEvent_transfer(msg.sender, _to, TICKER, _txhash);
    }

    function burn(bytes32 _txHash) public {
        emit NIP20TokenEvent_burn(msg.sender, TICKER, _txHash);
    }
}
