// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {AccountHandlerUpgradeable} from "../src/handlers/AccountHandlerUpgradeable.sol";
import {AssetHandlerUpgradeable} from "../src/handlers/AssetHandlerUpgradeable.sol";
import {FundsHandlerUpgradeable} from "../src/handlers/FundsHandlerUpgradeable.sol";
import {NuvoLockUpgradeable} from "../src/NuvoLockUpgradeable.sol";
import {TaskManagerUpgradeable} from "../src/tasks/TaskManagerUpgradeable.sol";
import {TaskSubmitterUpgradeable} from "../src/tasks/TaskSubmitterUpgradeable.sol";
import {ParticipantHandlerUpgradeable} from "../src/handlers/ParticipantHandlerUpgradeable.sol";
import {EntryPointUpgradeable} from "../src/EntryPointUpgradeable.sol";

contract Deploy is Script {
    address nuvoToken;
    address daoContract;
    address tssSigner;
    address[] initialParticipants;

    address vmProxy;
    address lockProxy;
    address pmProxy;
    address tmProxy;
    address tsProxy;
    address amProxy;
    address ahProxy;
    address dmProxy;
    address nip20Proxy;

    function setUp() public {
        // TODO: temporary dao contract
        daoContract = vm.envAddress("DAO_CONTRACT_ADDR");
        console.log("DAO contract addr: ", daoContract);
        nuvoToken = vm.envAddress("NUVO_TOKEN_ADDR");
        tssSigner = vm.envAddress("TSS_SIGNER_ADDR");
        initialParticipants.push(vm.envAddress("PARTICIPANT_1"));
        initialParticipants.push(vm.envAddress("PARTICIPANT_2"));
        initialParticipants.push(vm.envAddress("PARTICIPANT_3"));
    }

    function run() public {
        require(initialParticipants.length > 2, "Require at least 3 participant");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.createWallet(deployerPrivateKey).addr;
        console.log("Deployer address: ", deployer);
        vm.startBroadcast(deployerPrivateKey);

        // deploy votingManager proxy
        vmProxy = deployProxy(address(new EntryPointUpgradeable()), daoContract);

        // deploy nuvoLock
        lockProxy = deployProxy(address(new NuvoLockUpgradeable()), daoContract);
        NuvoLockUpgradeable nuvoLock = NuvoLockUpgradeable(lockProxy);
        nuvoLock.initialize(nuvoToken, deployer, vmProxy, 1 weeks, 1 ether);

        // deploy participantManager
        pmProxy = deployProxy(address(new ParticipantHandlerUpgradeable()), daoContract);
        ParticipantHandlerUpgradeable participantManager = ParticipantHandlerUpgradeable(pmProxy);
        participantManager.initialize(address(0), vmProxy, initialParticipants);

        // deploy taskManager & taskSubmitter
        tmProxy = deployProxy(address(new TaskManagerUpgradeable()), daoContract);
        tsProxy = deployProxy(address(new TaskSubmitterUpgradeable(tmProxy)), daoContract);

        TaskManagerUpgradeable taskManager = TaskManagerUpgradeable(tmProxy);
        TaskSubmitterUpgradeable taskSubmitter = TaskSubmitterUpgradeable(tsProxy);
        taskManager.initialize(tsProxy, vmProxy);
        taskSubmitter.initialize(vmProxy);

        // deploy assetHandler
        ahProxy = deployProxy(address(new AssetHandlerUpgradeable()), daoContract);
        AssetHandlerUpgradeable assetHandler = AssetHandlerUpgradeable(ahProxy);
        assetHandler.initialize(vmProxy);

        // deploy accountManager
        amProxy = deployProxy(address(new AccountHandlerUpgradeable()), daoContract);
        AccountHandlerUpgradeable accountManager = AccountHandlerUpgradeable(amProxy);
        accountManager.initialize(vmProxy);

        // deploy depositManager
        dmProxy = deployProxy(address(new FundsHandlerUpgradeable(ahProxy)), daoContract);
        FundsHandlerUpgradeable depositManager = FundsHandlerUpgradeable(dmProxy);
        depositManager.initialize(vmProxy);

        // initialize votingManager link to all contracts
        EntryPointUpgradeable votingManager = EntryPointUpgradeable(vmProxy);
        votingManager.initialize(
            tssSigner, // tssSigner
            pmProxy, // participantManager
            tmProxy, // taskManager
            lockProxy // nuvoLock
        );

        vm.stopBroadcast();
    }

    function deployProxy(address _logic, address _admin) internal returns (address) {
        return address(new TransparentUpgradeableProxy(_logic, _admin, ""));
    }
}
