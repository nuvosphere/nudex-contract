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

contract Deploy is Script {
    address daoContract;

    function setUp() public {
        // TODO: temporary dao contract
        daoContract = makeAddr("new_address");
    }

    function run() public {
        vm.startBroadcast();

        // deploy votingManager proxy
        address vmProxy = deployProxy(address(new VotingManagerUpgradeable()), daoContract);

        // deploy participantManager
        address pmProxy = deployProxy(address(new ParticipantManagerUpgradeable()), daoContract);
        ParticipantManagerUpgradeable participantManager = ParticipantManagerUpgradeable(pmProxy);
        participantManager.initialize(address(0), 0, 0, vmProxy, address(this));

        // deploy nuDexOperations
        address operationProxy = deployProxy(
            address(new NuDexOperationsUpgradeable()),
            daoContract
        );
        NuDexOperationsUpgradeable nuDexOperations = NuDexOperationsUpgradeable(operationProxy);
        nuDexOperations.initialize(address(participantManager), vmProxy);

        // deploy accountManager
        address amProxy = deployProxy(address(new AccountManagerUpgradeable()), daoContract);
        AccountManagerUpgradeable accountManager = AccountManagerUpgradeable(amProxy);
        accountManager.initialize(vmProxy);

        // deploy depositManager and NIP20 contract
        address dmProxy = deployProxy(address(new DepositManagerUpgradeable()), daoContract);
        address nip20Proxy = deployProxy(address(new NIP20Upgradeable()), daoContract);
        NIP20Upgradeable nip20 = NIP20Upgradeable(nip20Proxy);
        nip20.initialize(dmProxy);
        DepositManagerUpgradeable depositManager = DepositManagerUpgradeable(dmProxy);
        depositManager.initialize(vmProxy, nip20Proxy);

        // initialize votingManager link to all contracts
        VotingManagerUpgradeable votingManager = VotingManagerUpgradeable(vmProxy);
        votingManager.initialize(
            amProxy, // accountManager
            address(0), // assetManager
            dmProxy, // depositManager
            pmProxy, // participantManager
            operationProxy, // nudeOperation
            address(0) // nuvoLock
        );

        vm.stopBroadcast();
    }

    function deployProxy(address _logic, address _admin) internal returns (address) {
        return address(new TransparentUpgradeableProxy(_logic, _admin, ""));
    }
}
