// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {NuvoProxy, ITransparentUpgradeableProxy} from "../src/proxies/NuvoProxy.sol";
import {AccountHandlerUpgradeable} from "../src/handlers/AccountHandlerUpgradeable.sol";
import {AssetManagerUpgradeable} from "../src/AssetManagerUpgradeable.sol";
import {AssetType, AssetParam, TokenInfo} from "../src/interfaces/IAssetManager.sol";
import {FundsHandlerUpgradeable, DepositParam, WithdrawalParam, ConsolidateTaskParam} from "../src/handlers/FundsHandlerUpgradeable.sol";
import {TaskManagerUpgradeable, State} from "../src/TaskManagerUpgradeable.sol";
import {IAccountHandler, AddressCategory} from "../src/interfaces/IAccountHandler.sol";

// this contract is only used for contract testing
contract MockData is Script {
    uint32 public constant DEFAULT_ACCOUNT = 10001;
    uint64 public constant CHAIN_ID = 0;
    bytes32 public constant TICKER = "TOKEN_TICKER_18";
    bytes32 public constant FUNDS_ROLE = keccak256("FUNDS_ROLE");
    bytes32 public constant ENTRYPOINT_ROLE = keccak256("ENTRYPOINT_ROLE");

    uint256 public deployerPrivateKey;
    address public deployer;

    TaskManagerUpgradeable taskManager;
    AccountHandlerUpgradeable accountHandler;
    AssetManagerUpgradeable assetManager;
    FundsHandlerUpgradeable fundsHandler;

    address[] public handlers;

    function setUp() public {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.createWallet(deployerPrivateKey).addr;
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        _setupContracts(true);

        assetData();
        // fundsData(0x4e554445585f555344435f313800000000000000000000000000000000000000, 59902);
        accountData();
        updateTask();

        vm.stopBroadcast();
    }

    function _setupContracts(bool _fromEnv) internal {
        if (_fromEnv) {
            taskManager = TaskManagerUpgradeable(vm.envAddress("TASK_MANAGER"));
            accountHandler = AccountHandlerUpgradeable(vm.envAddress("ACCOUNT_HANDLER"));
            assetManager = AssetManagerUpgradeable(vm.envAddress("ASSET_HANDLER"));
            fundsHandler = FundsHandlerUpgradeable(vm.envAddress("FUNDS_HANDLER"));
            // grant role to deployer
            taskManager.grantRole(ENTRYPOINT_ROLE, deployer);
            accountHandler.grantRole(ENTRYPOINT_ROLE, deployer);
            assetManager.grantRole(ENTRYPOINT_ROLE, deployer);
            fundsHandler.grantRole(ENTRYPOINT_ROLE, deployer);
        } else {
            taskManager = new TaskManagerUpgradeable();
            console.log("|TaskManager|", address(taskManager));

            // deploy accountHandler
            accountHandler = new AccountHandlerUpgradeable(address(taskManager));
            // NuvoProxy proxy = new NuvoProxy(address(accountHandler), vm.envAddress("PARTICIPANT_2"));
            // accountHandler = AccountHandlerUpgradeable(address(proxy));
            accountHandler.initialize(deployer, deployer, deployer);
            handlers.push(address(accountHandler));
            console.log("|AccountHandler|", address(accountHandler));

            // deploy assetManager
            assetManager = new AssetManagerUpgradeable();
            // proxy = new NuvoProxy(address(assetManager), vm.envAddress("PARTICIPANT_2"));
            // assetManager = AssetManagerUpgradeable(address(proxy));
            assetManager.initialize(deployer);
            handlers.push(address(assetManager));
            console.log("|AssetManagerUpgradeable|", address(assetManager));

            // deploy fundsHandler
            fundsHandler = new FundsHandlerUpgradeable(
                address(accountHandler),
                address(assetManager),
                address(taskManager)
            );
            // proxy = new NuvoProxy(address(fundsHandler), vm.envAddress("PARTICIPANT_2"));
            // fundsHandler = FundsHandlerUpgradeable(address(proxy));
            fundsHandler.initialize(deployer, deployer, deployer, deployer);
            handlers.push(address(fundsHandler));
            assetManager.grantRole(FUNDS_ROLE, address(fundsHandler));
            console.log("|FundsHandlerUpgradeable|", address(fundsHandler));

            taskManager.initialize(deployer, deployer, handlers);
            console.log("Deployer address: ", deployer);
        }
    }

    function assetData() public {
        // asset
        AssetParam memory assetParam = AssetParam(18, true, true, 1 ether, 1 ether, "Token_Alias");
        assetManager.listNewAsset(TICKER, assetParam);
        TokenInfo[] memory testTokenInfo = new TokenInfo[](1);
        testTokenInfo[0] = TokenInfo(
            CHAIN_ID,
            AssetType.ERC20,
            true,
            uint8(18),
            "0xContractAddress",
            "SYMBOL",
            0
        );
        assetManager.linkToken(TICKER, testTokenInfo);

        assetManager.tokenSwitch(TICKER, CHAIN_ID, false);
        assetManager.tokenSwitch(TICKER, CHAIN_ID, true);

        // pause
        assetManager.setPauseState(TICKER, false);
        assetManager.setPauseState(bytes32(uint256(CHAIN_ID)), false);
    }

    function fundsData(bytes32 _ticker, uint64 _chainId) public {
        // deposit
        DepositParam[] memory depositInfos = new DepositParam[](1);
        depositInfos[0] = DepositParam(
            DEFAULT_ACCOUNT,
            _chainId,
            AddressCategory.EVM,
            _ticker,
            1 ether,
            "txHash",
            0,
            0
        );
        fundsHandler.submitDepositTask(depositInfos);
        fundsHandler.recordDeposit(depositInfos[0]);

        // withdraw
        WithdrawalParam[] memory withdrawalInfos = new WithdrawalParam[](1);
        withdrawalInfos[0] = WithdrawalParam(
            DEFAULT_ACCOUNT,
            _chainId,
            AddressCategory.EVM,
            _ticker,
            "124wd5urvxo4H3naXR6QACP1MGVpLeikeR",
            1 ether,
            bytes32(uint256(0))
        );

        fundsHandler.submitWithdrawTask(withdrawalInfos);
        fundsHandler.recordWithdrawal(
            DEFAULT_ACCOUNT,
            _chainId,
            _ticker,
            "124wd5urvxo4H3naXR6QACP1MGVpLeikeR",
            1 ether,
            0.1 ether,
            bytes32(uint256(0)),
            "TxHash"
        );

        // consolidate
        ConsolidateTaskParam[] memory consolidateTaskParams = new ConsolidateTaskParam[](3);
        consolidateTaskParams[0] = ConsolidateTaskParam(
            "fromAddr1",
            TICKER,
            CHAIN_ID,
            CHAIN_ID,
            1 ether,
            bytes32(uint256(0))
        );
        consolidateTaskParams[1] = ConsolidateTaskParam(
            "fromAddr2",
            TICKER,
            CHAIN_ID,
            CHAIN_ID,
            2.5 ether,
            bytes32(uint256(1))
        );
        consolidateTaskParams[2] = ConsolidateTaskParam(
            "fromAddr3",
            TICKER,
            CHAIN_ID,
            CHAIN_ID,
            3.3 ether,
            bytes32(uint256(2))
        );
        fundsHandler.submitConsolidateTask(consolidateTaskParams);
    }

    function accountData() public {
        for (uint8 i; i < 5; ++i) {
            accountHandler.registerNewAddress(
                makeAddr(Strings.toString(i)),
                10001 + i,
                AddressCategory.EVM,
                0,
                Strings.toHexString(makeAddr(Strings.toString(i)))
            );
        }

        accountHandler.registerNewAddress(
            makeAddr("address 1"),
            10001,
            AddressCategory.BTC,
            0,
            "124wd5urvxo4H3naXR6QACP1MGVpLeikeR"
        );
        accountHandler.registerNewAddress(
            makeAddr("address 2"),
            10002,
            AddressCategory.BTC,
            1,
            "1HkJEUpgptueutWRFB1bjHGKA5wtKBoToW"
        );
        accountHandler.registerNewAddress(
            makeAddr("address 3"),
            10003,
            AddressCategory.BTC,
            2,
            "1PS21zbYxJZUzsHg91MfxUDbqkn7BEw2C5"
        );

        accountHandler.registerNewAddress(
            makeAddr("address 1"),
            10001,
            AddressCategory.SOL,
            0,
            "w9A6215VdjCgX9BVwK1ZXE7sKBuNGh7bdmeGBEs7625"
        );
        accountHandler.registerNewAddress(
            makeAddr("address 2"),
            10002,
            AddressCategory.SOL,
            1,
            "4WMARsRWo8x7oJRwTQ9LhbDuiAnzz5TF3WzpTCgACrfe"
        );
        accountHandler.registerNewAddress(
            makeAddr("address 3"),
            10003,
            AddressCategory.SOL,
            2,
            "8ymc6niJiF4imco29UU3z7mK11sCt9NdL3LjG3VkEYAC"
        );
    }

    function updateTask() public {
        uint64[] memory taskIds = new uint64[](3);
        taskIds[0] = 0;
        taskIds[1] = 1;
        taskIds[2] = 2;
        State[] memory states = new State[](3);
        states[0] = State.Completed;
        states[1] = State.Pending;
        states[2] = State.Failed;
        taskManager.updateTask(taskIds, states);
    }
}
