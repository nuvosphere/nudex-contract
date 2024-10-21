pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {DepositManagerUpgradeable} from "../src/DepositManagerUpgradeable.sol";
import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";

contract AccountCreation is Test {
    address public daoContract;
    address public owner;
    DepositManagerUpgradeable public depositManager;
    VotingManagerUpgradeable public votingManager;

    function setUp() public {
        owner = address(this);
        daoContract = makeAddr("dao");

        // deploy votingManager
        votingManager = new VotingManagerUpgradeable();

        // deploy accountManager
        address proxy = Upgrades.deployTransparentProxy(
            "DepositManagerUpgradeable.sol",
            daoContract,
            abi.encodeCall(DepositManagerUpgradeable.initialize, address(votingManager))
        );
        depositManager = DepositManagerUpgradeable(proxy);
        assertEq(depositManager.owner(), address(votingManager));
    }

    function test_Deposit() public {
        // code
    }
}
