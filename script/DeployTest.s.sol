// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {MockNuvoToken} from "../src/mocks/MockNuvoToken.sol";

import {AccountHandlerUpgradeable} from "../src/handlers/AccountHandlerUpgradeable.sol";
import {FundsHandlerUpgradeable} from "../src/handlers/FundsHandlerUpgradeable.sol";
import {NuvoLockUpgradeable} from "../src/NuvoLockUpgradeable.sol";
import {TaskManagerUpgradeable} from "../src/tasks/TaskManagerUpgradeable.sol";
import {TaskSubmitter} from "../src/tasks/TaskSubmitter.sol";
import {ParticipantHandlerUpgradeable} from "../src/handlers/ParticipantHandlerUpgradeable.sol";
import {EntryPointUpgradeable} from "../src/EntryPointUpgradeable.sol";

// this contract is only used for contract testing
contract DeployTest is Script {
    address daoContract;
    address tssSigner;
    address[] initialParticipants;

    function setUp() public {
        // TODO: temporary dao contract
        daoContract = vm.envAddress("DAO_CONTRACT_ADDR");
        console.log("DAO contract addr: ", daoContract);

        tssSigner = vm.envAddress("TSS_SIGNER_ADDR");
        initialParticipants.push(vm.envAddress("PARTICIPANT_1"));
        initialParticipants.push(vm.envAddress("PARTICIPANT_2"));
        initialParticipants.push(vm.envAddress("PARTICIPANT_3"));
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.createWallet(deployerPrivateKey).addr;
        console.log("Deployer address: ", deployer);
        vm.startBroadcast(deployerPrivateKey);

        MockNuvoToken nuvoToken = new MockNuvoToken();
        console.log("|NuvoToken|", address(nuvoToken));

        // deploy votingManager proxy
        EntryPointUpgradeable votingManager = new EntryPointUpgradeable();
        console.log("|EntryPoint| ", address(votingManager));

        // deploy nuvoLock
        NuvoLockUpgradeable nuvoLock = new NuvoLockUpgradeable();
        nuvoLock.initialize(address(nuvoToken), deployer, address(votingManager), 300, 10);
        console.log("|NuvoLock|", address(nuvoLock));

        // deploy participantManager
        ParticipantHandlerUpgradeable participantManager = new ParticipantHandlerUpgradeable();
        participantManager.initialize(
            address(nuvoLock),
            address(votingManager),
            initialParticipants
        );
        console.log("|ParticipantHandler|", address(participantManager));

        // deploy taskManager
        TaskManagerUpgradeable taskManager = new TaskManagerUpgradeable();
        TaskSubmitter taskSubmitter = new TaskSubmitter(address(taskManager));
        console.log("|TaskSubmitter|", address(taskSubmitter));
        taskManager.initialize(address(taskSubmitter), address(votingManager));
        console.log("|TaskManager|", address(taskManager));

        // deploy accountManager
        AccountHandlerUpgradeable accountManager = new AccountHandlerUpgradeable();
        accountManager.initialize(address(votingManager));
        console.log("|AccountHandler|", address(accountManager));

        // deploy depositManager and NIP20 contract
        FundsHandlerUpgradeable depositManager = new FundsHandlerUpgradeable();
        depositManager.initialize(address(votingManager));
        console.log("|FundsHandler|", address(depositManager));

        // initialize votingManager link to all contracts
        votingManager.initialize(
            tssSigner, // tssSigner
            address(participantManager), // participantManager
            address(taskManager), // taskManager
            address(nuvoLock) // nuvoLock
        );

        vm.stopBroadcast();
    }
}
