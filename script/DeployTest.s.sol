// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {MockNuvoToken} from "../src/mocks/MockNuvoToken.sol";

import {AccountHandlerUpgradeable} from "../src/handlers/AccountHandlerUpgradeable.sol";
import {AssetHandlerUpgradeable} from "../src/handlers/AssetHandlerUpgradeable.sol";
import {FundsHandlerUpgradeable} from "../src/handlers/FundsHandlerUpgradeable.sol";
import {NuvoLockUpgradeable} from "../src/NuvoLockUpgradeable.sol";
import {TaskManagerUpgradeable} from "../src/TaskManagerUpgradeable.sol";
import {ParticipantHandlerUpgradeable} from "../src/handlers/ParticipantHandlerUpgradeable.sol";
import {EntryPointUpgradeable} from "../src/EntryPointUpgradeable.sol";

// this contract is only used for contract testing
contract DeployTest is Script {
    address daoContract;
    address tssSigner;
    address[] initialParticipants;
    address[] handlers;

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

        // deploy taskManager
        TaskManagerUpgradeable taskManager = new TaskManagerUpgradeable();
        console.log("|TaskManager|", address(taskManager));

        // deploy participantManager
        ParticipantHandlerUpgradeable participantManager = new ParticipantHandlerUpgradeable(
            address(nuvoLock),
            address(taskManager)
        );
        participantManager.initialize(
            daoContract,
            address(votingManager),
            deployer,
            initialParticipants
        );
        console.log("|ParticipantHandler|", address(participantManager));

        // deploy accountManager
        AccountHandlerUpgradeable accountManager = new AccountHandlerUpgradeable(
            address(taskManager)
        );
        accountManager.initialize(daoContract, address(votingManager), deployer);
        console.log("|AccountHandler|", address(accountManager));

        // deploy accountManager
        AssetHandlerUpgradeable assetHandler = new AssetHandlerUpgradeable(address(taskManager));
        assetHandler.initialize(daoContract, address(votingManager), deployer);
        console.log("|AssetHandler|", address(assetHandler));

        // deploy depositManager
        FundsHandlerUpgradeable depositManager = new FundsHandlerUpgradeable(
            address(assetHandler),
            address(taskManager)
        );
        depositManager.initialize(daoContract, address(votingManager), deployer);
        console.log("|FundsHandler|", address(depositManager));

        // initialize votingManager link to all contracts
        taskManager.initialize(daoContract, address(votingManager), handlers);
        votingManager.initialize(
            tssSigner, // tssSigner
            address(participantManager), // participantManager
            address(taskManager), // taskManager
            address(nuvoLock) // nuvoLock
        );

        vm.stopBroadcast();
    }
}
