pragma solidity ^0.8.0;

import "./BaseTest.sol";

import {Proxy} from "../src/Proxy.sol";
import {DepositManagerUpgradeable} from "../src/DepositManagerUpgradeable.sol";
import {IDepositManager} from "../src/interfaces/IDepositManager.sol";
import {NuDexOperationsUpgradeable} from "../src/NuDexOperationsUpgradeable.sol";
import {INuDexOperations} from "../src/interfaces/INuDexOperations.sol";
import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";

import {MockParticipantManager} from "../src/mocks/MockParticipantManager.sol";
import {MockNuvoLockUpgradeable} from "../src/mocks/MockNuvoLockUpgradeable.sol";

contract Withdraw is BaseTest {
    address public depositAddress;
    address public user;

    DepositManagerUpgradeable public depositManager;
    NuDexOperationsUpgradeable public nuDexOperations;
    VotingManagerUpgradeable public votingManager;
    MockParticipantManager public participantManager;
    MockNuvoLockUpgradeable public nuvoLock;

    function setUp() public override {
        super.setUp();
        depositAddress = makeAddr("new_address");
        user = makeAddr("user");

        // deploy mock contract
        participantManager = new MockParticipantManager(owner);
        nuvoLock = new MockNuvoLockUpgradeable();

        // deploy votingManager proxy
        address vmProxy = deployProxy(address(new VotingManagerUpgradeable()), daoContract);

        // deploy nuDexOperations
        address operationProxy = deployProxy(
            address(new NuDexOperationsUpgradeable()),
            daoContract
        );
        nuDexOperations = NuDexOperationsUpgradeable(operationProxy);
        nuDexOperations.initialize(address(participantManager), vmProxy);
        assertEq(nuDexOperations.owner(), vmProxy);

        // initialize votingManager link to all contracts
        votingManager = VotingManagerUpgradeable(vmProxy);
        votingManager.initialize(
            address(0), // accountManager
            address(0), // assetManager
            address(0), // depositManager
            address(participantManager), // participantManager
            operationProxy, // nudeOperation
            address(nuvoLock) // nuvoLock
        );
    }

    function test_Withdraw() public {
        // --- withdraw request ---
    }
}
