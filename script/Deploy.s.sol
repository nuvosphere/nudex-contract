// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {AccountManagerUpgradeable} from "../src/AccountManagerUpgradeable.sol";
import {DepositManagerUpgradeable} from "../src/DepositManagerUpgradeable.sol";
import {NIP20Upgradeable} from "../src/NIP20Upgradeable.sol";
import {NuvoLockUpgradeable} from "../src/NuvoLockUpgradeable.sol";
import {TaskManagerUpgradeable} from "../src/TaskManagerUpgradeable.sol";
import {TaskSubmitter} from "../src/TaskSubmitter.sol";
import {ParticipantManagerUpgradeable} from "../src/ParticipantManagerUpgradeable.sol";
import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";

contract Deploy is Script {
    address nuvoToken;
    address daoContract;
    address[] initialParticipants;

    address vmProxy;
    address lockProxy;
    address pmProxy;
    address tmProxy;
    address amProxy;
    address dmProxy;
    address nip20Proxy;

    function setUp() public {
        // TODO: temporary dao contract
        daoContract = vm.envAddress("DAO_CONTRACT_ADDR");
        console.log("DAO contract addr: ", daoContract);
        nuvoToken = vm.envAddress("NUVO_TOKEN_ADDR");
    }

    function run() public {
        require(initialParticipants.length > 2, "Require at least 3 participant");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.createWallet(deployerPrivateKey).addr;
        console.log("Deployer address: ", deployer);
        vm.startBroadcast(deployerPrivateKey);

        // deploy votingManager proxy
        vmProxy = deployProxy(address(new VotingManagerUpgradeable()), daoContract);

        // deploy nuvoLock
        lockProxy = deployProxy(address(new NuvoLockUpgradeable()), daoContract);
        NuvoLockUpgradeable nuvoLock = NuvoLockUpgradeable(lockProxy);
        nuvoLock.initialize(nuvoToken, deployer, vmProxy, 1 weeks, 1 ether);

        // deploy participantManager
        pmProxy = deployProxy(address(new ParticipantManagerUpgradeable()), daoContract);
        ParticipantManagerUpgradeable participantManager = ParticipantManagerUpgradeable(pmProxy);
        participantManager.initialize(address(0), vmProxy, initialParticipants);

        // deploy taskManager
        tmProxy = deployProxy(address(new TaskManagerUpgradeable()), daoContract);
        TaskManagerUpgradeable taskManager = TaskManagerUpgradeable(tmProxy);
        taskManager.initialize(address(new TaskSubmitter(tmProxy)), vmProxy);

        // deploy accountManager
        amProxy = deployProxy(address(new AccountManagerUpgradeable()), daoContract);
        AccountManagerUpgradeable accountManager = AccountManagerUpgradeable(amProxy);
        accountManager.initialize(vmProxy);

        // deploy depositManager and NIP20 contract
        dmProxy = deployProxy(address(new DepositManagerUpgradeable()), daoContract);
        nip20Proxy = deployProxy(address(new NIP20Upgradeable()), daoContract);
        NIP20Upgradeable nip20 = NIP20Upgradeable(nip20Proxy);
        nip20.initialize(dmProxy);
        DepositManagerUpgradeable depositManager = DepositManagerUpgradeable(dmProxy);
        depositManager.initialize(vmProxy, nip20Proxy);

        // initialize votingManager link to all contracts
        VotingManagerUpgradeable votingManager = VotingManagerUpgradeable(vmProxy);
        votingManager.initialize(
            deployer,
            amProxy, // accountManager
            address(0), // assetManager
            dmProxy, // depositManager
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
