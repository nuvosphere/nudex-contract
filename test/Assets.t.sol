pragma solidity ^0.8.0;

import "./BaseTest.sol";
import {TestHelper} from "./utils/TestHelper.sol";

import {AssetManagerUpgradeable} from "../src/AssetManagerUpgradeable.sol";
import {IAssetManager, AssetType, AssetParam, Pair, PairState, PairType, TokenInfo} from "../src/interfaces/IAssetManager.sol";
import {ITaskManager, Task} from "../src/interfaces/ITaskManager.sol";

contract AssetsTest is BaseTest {
    bytes32 public constant TICKER = "TOKEN_TICKER_18";
    uint64 public constant CHAIN_ID = 1;
    uint256 public constant MIN_DEPOSIT_AMOUNT = 50;
    uint256 public constant MIN_WITHDRAW_AMOUNT = 50;

    AssetManagerUpgradeable public assetManager;

    function setUp() public override {
        super.setUp();

        // setup assetManager
        address assetManagerProxy = _deployProxy(
            address(new AssetManagerUpgradeable()),
            daoContract
        );
        assetManager = AssetManagerUpgradeable(assetManagerProxy);
        assetManager.initialize(daoContract, daoContract);

        // assign handlers
        vm.startPrank(daoContract);
        assetManager.grantRole(assetManager.ADMIN_ROLE(), msgSender);
        handlers.push(assetManagerProxy);
        taskManager.initialize(daoContract, entryPointProxy, handlers);

        // list new asset and token
        AssetParam memory assetParam = AssetParam(
            18,
            true,
            true,
            MIN_DEPOSIT_AMOUNT,
            MIN_WITHDRAW_AMOUNT,
            ""
        );
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
        vm.stopPrank();
    }

    function test_AssetOperations() public {
        vm.startPrank(daoContract);
        // list asset
        bytes32 assetBTicker = "TOKEN_TICKER_10";
        assertEq(assetManager.getAllAssets().length, 1);
        AssetParam memory assetParam = AssetParam(10, false, false, 0, 0, "Token02");
        assetManager.listNewAsset(assetBTicker, assetParam);
        assertEq(assetManager.getAllAssets().length, 2);

        // update listed asset
        assertEq(assetManager.getAssetDetails(TICKER).decimals, 18);
        assetParam = AssetParam(10, false, true, 0, MIN_WITHDRAW_AMOUNT, "Token01");
        assetManager.updateAsset(TICKER, assetParam);
        assertEq(assetManager.getAssetDetails(TICKER).decimals, 10);

        // add pair
        Pair[] memory pairs = new Pair[](1);
        pairs[0] = Pair(
            TICKER,
            assetBTicker,
            PairState.Active,
            PairType.Spot,
            18,
            18,
            0,
            0,
            3 ether,
            1 ether,
            30 ether,
            10 ether
        );
        assetManager.addPair(pairs);
        // check index, should match 1 both ways
        assertEq(assetManager.getPairIndex(TICKER, assetBTicker), 1);
        assertEq(assetManager.getPairIndex(assetBTicker, TICKER), 1);
        assertEq(assetManager.getPairInfo(assetBTicker, TICKER).listedTime, block.timestamp);
        assertEq(assetManager.getPairInfo(assetBTicker, TICKER).activeTime, block.timestamp);

        // link new token
        TokenInfo[] memory newTokens = new TokenInfo[](2);
        newTokens[0] = TokenInfo(
            uint64(0x02),
            AssetType.ERC20,
            true,
            uint8(18),
            "0xNewTokenContractAddress",
            "TOKEN_SYMBOL",
            1 ether
        );
        newTokens[1] = TokenInfo(
            uint64(0x03),
            AssetType.ERC20,
            true,
            uint8(18),
            "0xNewTokenContractAddress2",
            "TOKEN_SYMBOL2",
            5 ether
        );
        assetManager.linkToken(TICKER, newTokens);
        assertEq(assetManager.getAllLinkedTokens(TICKER).length, 3);
        assertEq(assetManager.linkedTokenList(TICKER, 2), uint64(0x03));

        // update linked token
        TokenInfo memory tokenInfo = TokenInfo(
            uint64(0x01),
            AssetType.ERC20,
            true,
            uint8(18),
            "0xNewTokenContractAddress",
            "TOKEN_SYMBOL",
            2 ether
        );
        assetManager.updateToken(TICKER, tokenInfo);
        assertEq(assetManager.getLinkedToken(TICKER, CHAIN_ID).withdrawFee, 2 ether);
        // fail case: update non-existing token
        tokenInfo.chainId = uint64(0x99);
        vm.expectRevert("Token not linked");
        assetManager.updateToken(TICKER, tokenInfo);

        // deactive token
        assertTrue(assetManager.getLinkedToken(TICKER, CHAIN_ID).isActive);
        assetManager.tokenSwitch(TICKER, CHAIN_ID, false);
        assertFalse(assetManager.getLinkedToken(TICKER, CHAIN_ID).isActive);

        // unlink tokens
        assetManager.resetLinkedToken(TICKER);
        signature = _generateOptSignature(taskOpts, tssKey);
        assertFalse(assetManager.getLinkedToken(TICKER, CHAIN_ID).isActive);

        // delist asset
        assertTrue(assetManager.isAssetListed(TICKER));
        assetManager.delistAsset(TICKER);
        vm.expectRevert(abi.encodeWithSelector(IAssetManager.AssetNotListed.selector, TICKER));
        assetManager.getAssetDetails(TICKER);
        assertFalse(assetManager.isAssetListed(TICKER));

        vm.stopPrank();
    }

    function test_Pause() public {
        assertFalse(assetManager.pauseState(TICKER));
        vm.prank(daoContract);
        assetManager.setPauseState(TICKER, true);
        assertTrue(assetManager.pauseState(TICKER));
    }
}
