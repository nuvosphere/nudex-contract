pragma solidity ^0.8.0;

import "./BaseTest.sol";

import {AssetHandlerUpgradeable, AssetParam, AssetType, TokenInfo} from "../src/handlers/AssetHandlerUpgradeable.sol";
import {ITaskManager, TaskOperation} from "../src/interfaces/ITaskManager.sol";

contract AssetsTest is BaseTest {
    bytes32 public constant TICKER = "TOKEN_TICKER_18";
    bytes32 public constant FUNDS_ROLE = keccak256("FUNDS_ROLE");
    bytes32 public constant CHAIN_ID = 0;
    uint256 public constant MIN_DEPOSIT_AMOUNT = 50;
    uint256 public constant MIN_WITHDRAW_AMOUNT = 50;

    AssetHandlerUpgradeable public assetHandler;

    address public ahProxy;

    function setUp() public override {
        super.setUp();

        // setup assetHandler
        ahProxy = _deployProxy(
            address(new AssetHandlerUpgradeable(address(taskManager))),
            daoContract
        );
        assetHandler = AssetHandlerUpgradeable(ahProxy);
        assetHandler.initialize(daoContract, vmProxy, msgSender);

        // assign handlers
        vm.prank(daoContract);
        assetHandler.grantRole(FUNDS_ROLE, msgSender);
        handlers.push(ahProxy);
        taskManager.initialize(daoContract, vmProxy, handlers);
    }

    function test_ListAsset() public {
        vm.startPrank(vmProxy);
        AssetParam memory assetParam = AssetParam(
            AssetType.BTC,
            18,
            true,
            true,
            MIN_DEPOSIT_AMOUNT,
            MIN_WITHDRAW_AMOUNT,
            "",
            ""
        );
        assetHandler.listNewAsset(TICKER, assetParam);
        TokenInfo[] memory testTokenInfo = new TokenInfo[](1);
        testTokenInfo[0] = TokenInfo(
            CHAIN_ID,
            true,
            AssetType.BTC,
            uint8(18),
            address(0),
            "SYMBOL",
            0,
            100 ether,
            100 ether
        );
        assetHandler.linkToken(TICKER, testTokenInfo);

        vm.stopPrank();

        vm.startPrank(msgSender);
        taskIds[0] = assetHandler.submitConsolidateTask(TICKER);
        TaskOperation memory task = taskManager.getTask(taskIds[0]);
        bytes[] memory callData = new bytes[](1);
        callData[0] = abi.encode(TICKER, CHAIN_ID, 1 ether, 0);
        bytes memory signature = _generateDataSignature(
            abi.encode(taskIds, callData, entryPoint.tssNonce(), block.chainid),
            tssKey
        );
        entryPoint.pendingTask(taskIds, callData, signature);
        task = taskManager.getTask(taskIds[0]);
        signature = _generateOptSignature(taskIds, tssKey);
        entryPoint.verifyAndCall(taskIds, signature);
    }
}
