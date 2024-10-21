pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {AccountManagerUpgradeable} from "../contracts/AccountManager.sol";
import {VotingManager} from "../contracts/VotingManager.sol";

contract ContractAccountCreation is Test {
    AccountManagerUpgradeable public accountManager;
    VotingManager public votingManager;

    function setUp() public {
        votingManager = new VotingManager();
    }

    function test_Create() public {
        // votingManager.registerAccount();
        // assertEq(accountManager.addressRecord(), );
    }
}
