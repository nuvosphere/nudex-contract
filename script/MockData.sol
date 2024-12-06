// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {NuvoProxy, ITransparentUpgradeableProxy} from "../src/proxies/NuvoProxy.sol";
import {AccountHandlerUpgradeable} from "../src/handlers/AccountHandlerUpgradeable.sol";
import {IAccountHandler} from "../src/interfaces/IAccountHandler.sol";

// this contract is only used for contract testing
contract MockData is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.createWallet(deployerPrivateKey).addr;
        console.log("Deployer address: ", deployer);
        vm.startBroadcast(deployerPrivateKey);

        // deploy accountManager
        AccountHandlerUpgradeable accountManager = new AccountHandlerUpgradeable();
        NuvoProxy proxy = new NuvoProxy(address(accountManager), vm.envAddress("PARTICIPANT_2"));
        accountManager = AccountHandlerUpgradeable(address(proxy));
        accountManager.initialize(address(deployer));
        console.log("|AccountHandler|", address(accountManager));

        for (uint8 i; i < 10; ++i) {
            accountManager.registerNewAddress(
                10001,
                IAccountHandler.Chain.EVM,
                i,
                Strings.toHexString(makeAddr(Strings.toString(i)))
            );
        }

        accountManager.registerNewAddress(
            10002,
            IAccountHandler.Chain.BTC,
            0,
            "124wd5urvxo4H3naXR6QACP1MGVpLeikeR"
        );
        accountManager.registerNewAddress(
            10002,
            IAccountHandler.Chain.BTC,
            1,
            "1HkJEUpgptueutWRFB1bjHGKA5wtKBoToW"
        );
        accountManager.registerNewAddress(
            10002,
            IAccountHandler.Chain.BTC,
            2,
            "1PS21zbYxJZUzsHg91MfxUDbqkn7BEw2C5"
        );

        accountManager.registerNewAddress(
            10003,
            IAccountHandler.Chain.SOL,
            0,
            "w9A6215VdjCgX9BVwK1ZXE7sKBuNGh7bdmeGBEs7625"
        );
        accountManager.registerNewAddress(
            10003,
            IAccountHandler.Chain.SOL,
            1,
            "4WMARsRWo8x7oJRwTQ9LhbDuiAnzz5TF3WzpTCgACrfe"
        );
        accountManager.registerNewAddress(
            10003,
            IAccountHandler.Chain.SOL,
            2,
            "8ymc6niJiF4imco29UU3z7mK11sCt9NdL3LjG3VkEYAC"
        );

        vm.stopBroadcast();
    }
}
