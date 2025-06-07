// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {AccountHandlerUpgradeable} from "../src/handlers/AccountHandlerUpgradeable.sol";
import {AssetManagerUpgradeable} from "../src/AssetManagerUpgradeable.sol";
import {FundsHandlerUpgradeable} from "../src/handlers/FundsHandlerUpgradeable.sol";
import {NuvoLockUpgradeable} from "../src/NuvoLockUpgradeable.sol";
import {NuvoToken} from "../src/dao/NuvoToken.sol";
import {TaskManagerUpgradeable} from "../src/TaskManagerUpgradeable.sol";
import {ParticipantHandlerUpgradeable} from "../src/handlers/ParticipantHandlerUpgradeable.sol";
import {EntryPointUpgradeable} from "../src/EntryPointUpgradeable.sol";
import {NuvoProxy} from "../src/proxies/NuvoProxy.sol";

contract Deploy is Script {
    address nuvoToken;
    address proxyAdminOwner;
    address daoContract;
    address nuvoTokenHolder;
    address feeReceiver;
    address tssSigner;
    address submitter;
    address tracker;
    address participantTaskSubmitter;

    address[] initialParticipants;
    address[] handlers;
    address proxyAdminContract;

    address entryPointProxy;
    address nuvoLockProxy;
    address participantHandlerProxy;
    address taskManagerProxy;
    address accountHandlerProxy;
    address assetManagerProxy;
    address fundsHandlerProxy;

    function setUp() public {
        // TODO: temporary dao contract
        proxyAdminOwner = vm.envAddress("PROXY_ADMIN_OWNER");
        daoContract = vm.envAddress("DAO_CONTRACT_ADDR");
        nuvoTokenHolder = vm.envAddress("NUVO_TOKEN_HOLDER");
        feeReceiver = vm.envAddress("FEE_RECEIVER_ADDR");
        tssSigner = vm.envAddress("TSS_SIGNER_ADDR");
        submitter = vm.envAddress("SUBMITTER_ADDR");
        tracker = vm.envAddress("TRACKER_ADDR");
        participantTaskSubmitter = vm.envAddress("PARTICIPANT_TASK_SUBMITTER");

        initialParticipants.push(vm.envAddress("PARTICIPANT_1"));
        initialParticipants.push(vm.envAddress("PARTICIPANT_2"));
        initialParticipants.push(vm.envAddress("PARTICIPANT_3"));

        console.log("Proxy admin addr: ", proxyAdminOwner);
        console.log("DAO contract addr: ", daoContract);
        console.log("Nuvo token holder addr: ", nuvoTokenHolder);
        console.log("Fee receiver addr: ", feeReceiver);
        console.log("TSS signer addr: ", tssSigner);
        console.log("Submitter", submitter);
        console.log("Tracker", tracker);
        console.log("Participant task submitter", participantTaskSubmitter);
        for (uint8 i; i < initialParticipants.length; ++i) {
            console.log("participant", i, " address: ", initialParticipants[i]);
        }
    }

    function run() public {
        require(initialParticipants.length > 2, "Require at least 3 participant");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.createWallet(deployerPrivateKey).addr;
        console.log("\n  Deployer address: ", deployer);

        vm.startBroadcast(deployerPrivateKey);
        setProxyAdmin(true);

        setNuvoToken(true);
        deployTopLevel(false);
        deployHandlers(true);

        vm.stopBroadcast();
    }

    function setProxyAdmin(bool _fromEnv) public {
        if (_fromEnv) {
            proxyAdminContract = vm.envAddress("PROXY_ADMIN_CONTRACT");
        } else {
            ProxyAdmin proxyAdmin = new ProxyAdmin(proxyAdminOwner);
            proxyAdminContract = address(proxyAdmin);
        }
        console.log("Proxy Admin", proxyAdminContract);
        console.log("Proxy owner", ProxyAdmin(proxyAdminContract).owner());
    }

    function setNuvoToken(bool _fromEnv) public {
        if (_fromEnv) {
            nuvoToken = vm.envAddress("NUVO_TOKEN_ADDR");
        } else {
            NuvoToken nuvoTokenContract = new NuvoToken(nuvoTokenHolder);
            nuvoToken = address(nuvoTokenContract);
            console.log(
                "NuvoToken holder",
                nuvoTokenHolder,
                nuvoTokenContract.balanceOf(nuvoTokenHolder)
            );
        }
    }

    function deployTopLevel(bool _fromEnv) public {
        if (_fromEnv) {
            entryPointProxy = vm.envAddress("ENTRY_POINT");
            nuvoLockProxy = vm.envAddress("NUVO_LOCK_ADDR");
        } else {
            // deploy entryPoint
            entryPointProxy = deployProxy(address(new EntryPointUpgradeable()));

            // deploy nuvoLock
            nuvoLockProxy = deployProxy(address(new NuvoLockUpgradeable(nuvoToken)));
            NuvoLockUpgradeable nuvoLock = NuvoLockUpgradeable(nuvoLockProxy);
            nuvoLock.initialize(nuvoTokenHolder, daoContract, entryPointProxy, 1 ether, 1 days);

            // deploy assetManager
            assetManagerProxy = deployProxy(address(new AssetManagerUpgradeable()));
            AssetManagerUpgradeable assetManager = AssetManagerUpgradeable(assetManagerProxy);
            assetManager.initialize(daoContract, submitter);
        }

        console.log("\n  |NuvoToken|", nuvoToken);
        console.log("|EntryPoint| ", entryPointProxy);
        console.log("|NuvoLock|", nuvoLockProxy);
        console.log("|AssetManager|", assetManagerProxy);
    }

    function deployHandlers(bool _entryPointInit) public {
        // deploy taskManager
        taskManagerProxy = deployProxy(address(new TaskManagerUpgradeable()));
        TaskManagerUpgradeable taskManager = TaskManagerUpgradeable(taskManagerProxy);
        console.log("|TaskManager|", address(taskManager));

        // deploy participantHandler
        participantHandlerProxy = deployProxy(
            address(new ParticipantHandlerUpgradeable(nuvoLockProxy, taskManagerProxy))
        );
        ParticipantHandlerUpgradeable participantHandler = ParticipantHandlerUpgradeable(
            participantHandlerProxy
        );
        participantHandler.initialize(
            daoContract,
            entryPointProxy,
            participantTaskSubmitter,
            initialParticipants
        );
        handlers.push(participantHandlerProxy);
        handlers.push(address(participantHandler));
        console.log("|ParticipantHandler|", participantHandlerProxy);

        // deploy accountHandler
        accountHandlerProxy = deployProxy(address(new AccountHandlerUpgradeable(taskManagerProxy)));
        AccountHandlerUpgradeable accountHandler = AccountHandlerUpgradeable(accountHandlerProxy);
        accountHandler.initialize(daoContract, entryPointProxy, submitter);
        handlers.push(accountHandlerProxy);
        console.log("|AccountHandler|", accountHandlerProxy);

        // deploy fundsHandler
        fundsHandlerProxy = deployProxy(
            address(
                new FundsHandlerUpgradeable(
                    accountHandlerProxy,
                    assetManagerProxy,
                    taskManagerProxy
                )
            )
        );
        FundsHandlerUpgradeable fundsHandler = FundsHandlerUpgradeable(fundsHandlerProxy);
        fundsHandler.initialize(daoContract, entryPointProxy, submitter, tracker, feeReceiver);
        handlers.push(fundsHandlerProxy);
        console.log("|FundsHandler|", fundsHandlerProxy);

        // initialize entryPoint link to all contracts
        taskManager.initialize(daoContract, entryPointProxy, handlers);
        if (_entryPointInit) {
            EntryPointUpgradeable entryPoint = EntryPointUpgradeable(entryPointProxy);
            entryPoint.initialize(
                tssSigner, // tssSigner
                participantHandlerProxy, // participantHandler
                taskManagerProxy, // taskManager
                nuvoLockProxy // nuvoLock
            );
        }
    }

    function deployProxy(address _logic) internal returns (address) {
        return address(new NuvoProxy(_logic, proxyAdminContract));
    }
}
