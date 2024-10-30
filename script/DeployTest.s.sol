// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {AccountManagerUpgradeable} from "../src/AccountManagerUpgradeable.sol";
import {DepositManagerUpgradeable} from "../src/DepositManagerUpgradeable.sol";
import {NIP20Upgradeable} from "../src/NIP20Upgradeable.sol";
import {NuDexOperationsUpgradeable} from "../src/NuDexOperationsUpgradeable.sol";
import {ParticipantManagerUpgradeable} from "../src/ParticipantManagerUpgradeable.sol";
import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";

// this contract is only used for contract testing
contract DeployTest is Script {
    address daoContract;

    function setUp() public {
        // TODO: temporary dao contract
        daoContract = vm.envAddress("DAO_CONTRACT_ADDR");
        console.log("DAO contract addr: ", daoContract);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.createWallet(deployerPrivateKey).addr;
        console.log("Deployer address: ", deployer);
        vm.startBroadcast(deployerPrivateKey);

        // deploy votingManager proxy
        VotingManagerUpgradeable votingManager = new VotingManagerUpgradeable();
        console.log("VotingManager: ", address(votingManager));

        // deploy participantManager
        ParticipantManagerUpgradeable participantManager = new ParticipantManagerUpgradeable();
        address[] memory initParticipant = new address[](3);
        initParticipant[0] = deployer;
        initParticipant[1] = deployer;
        initParticipant[2] = deployer;
        participantManager.initialize(address(0), address(votingManager), initParticipant);
        console.log("participantManager: ", address(participantManager));

        // deploy nuDexOperations
        NuDexOperationsUpgradeable nuDexOperations = new NuDexOperationsUpgradeable();
        nuDexOperations.initialize(address(participantManager), address(votingManager));
        console.log("NuDexOperations: ", address(nuDexOperations));

        // deploy accountManager
        AccountManagerUpgradeable accountManager = new AccountManagerUpgradeable();
        accountManager.initialize(address(votingManager));
        console.log("AccountManager: ", address(accountManager));

        // deploy depositManager and NIP20 contract
        DepositManagerUpgradeable depositManager = new DepositManagerUpgradeable();
        NIP20Upgradeable nip20 = new NIP20Upgradeable();
        nip20.initialize(address(depositManager));
        depositManager.initialize(address(votingManager), address(nip20));
        console.log("DepositManager: ", address(depositManager));

        // initialize votingManager link to all contracts
        votingManager.initialize(
            deployer,
            address(accountManager), // accountManager
            address(0), // assetManager
            address(depositManager), // depositManager
            address(participantManager), // participantManager
            address(nuDexOperations), // nudeOperation
            address(0) // nuvoLock
        );

        vm.stopBroadcast();
    }
}
