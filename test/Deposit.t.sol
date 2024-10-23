pragma solidity ^0.8.0;

import "./BaseTest.sol";

import {Proxy} from "../src/Proxy.sol";
import {DepositManagerUpgradeable} from "../src/DepositManagerUpgradeable.sol";
import {IDepositManager} from "../src/interfaces/IDepositManager.sol";
import {NuDexOperationsUpgradeable} from "../src/NuDexOperationsUpgradeable.sol";
import {INuDexOperations} from "../src/interfaces/INuDexOperations.sol";
import {VotingManagerUpgradeable} from "../src/VotingManagerUpgradeable.sol";

import {MockParticipantManager} from "../src/mocks/MockParticipantManager.sol";
import {MockNuvoLockUpgradeable} from "../src/mocks/MockNuvoLockUpgradeable.sol";

contract AccountCreation is BaseTest {
    address public depositAddress;
    address public user;

    DepositManagerUpgradeable public depositManager;
    NuDexOperationsUpgradeable public nuDexOperations;
    VotingManagerUpgradeable public votingManager;
    MockParticipantManager public participantManager;
    MockNuvoLockUpgradeable public nuvoLock;

    function setUp() public override {
        super.setUp();
        depositAddress = makeAddr("new_address");
        user = makeAddr("user");

        // deploy mock contract
        participantManager = new MockParticipantManager(owner);
        nuvoLock = new MockNuvoLockUpgradeable();

        // deploy votingManager
        address vmLogic = address(new VotingManagerUpgradeable());
        address vmProxy = address(new TransparentUpgradeableProxy(vmLogic, daoContract, ""));

        // deploy nuDexOperations
        address operationLogic = address(new NuDexOperationsUpgradeable());
        address operationProxy = address(
            new TransparentUpgradeableProxy(operationLogic, daoContract, "")
        );
        nuDexOperations = NuDexOperationsUpgradeable(operationProxy);
        nuDexOperations.initialize(address(participantManager), vmProxy);
        assertEq(nuDexOperations.owner(), vmProxy);

        // deploy depositManager
        address dmLogic = address(new DepositManagerUpgradeable());
        address dmProxy = address(new TransparentUpgradeableProxy(dmLogic, daoContract, ""));
        depositManager = DepositManagerUpgradeable(dmProxy);
        depositManager.initialize(vmProxy);
        assertEq(depositManager.owner(), vmProxy);

        // initialize votingManager link to all contracts
        votingManager = VotingManagerUpgradeable(vmProxy);
        votingManager.initialize(
            address(0), // accountManager
            address(0), // assetManager
            dmProxy, // depositManager
            address(participantManager), // participantManager
            operationProxy, // nudeOperation
            address(nuvoLock) // nuvoLock
        );
    }

    function test_Deposit() public {
        vm.startPrank(owner);
        // first deposit
        // setup deposit info
        uint256 depositIndex = depositManager.getDeposits(user).length;
        assertEq(depositIndex, 0);
        uint256 depositAmount = 1 ether;
        uint256 chainId = 0;
        bytes memory txInfo = "--- encoded tx info ---";
        bytes memory extraInfo = "--- extra info ---";
        bytes memory encodedParams = abi.encodePacked(
            user,
            depositAmount,
            chainId,
            txInfo,
            extraInfo
        );
        bytes memory signature = generateSignature(encodedParams, privKey);

        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IDepositManager.DepositRecorded(user, depositAmount, chainId, txInfo, extraInfo);
        votingManager.submitDepositInfo(user, depositAmount, chainId, txInfo, extraInfo, signature);
        IDepositManager.DepositInfo memory depositInfo = depositManager.getDeposit(
            user,
            depositIndex
        );
        assertEq(
            encodedParams,
            abi.encodePacked(
                depositInfo.targetAddress,
                depositInfo.amount,
                depositInfo.chainId,
                depositInfo.txInfo,
                depositInfo.extraInfo
            )
        );

        // second deposit
        // setup deposit info
        depositIndex = depositManager.getDeposits(user).length;
        assertEq(depositIndex, 1); // should have increased by 1
        depositAmount = 5 ether;
        chainId = 10;
        txInfo = "--- encoded tx info 2 ---";
        extraInfo = "--- extra info 2 ---";
        encodedParams = abi.encodePacked(user, depositAmount, chainId, txInfo, extraInfo);
        signature = generateSignature(encodedParams, privKey);

        // check event and result
        vm.expectEmit(true, true, true, true);
        emit IDepositManager.DepositRecorded(user, depositAmount, chainId, txInfo, extraInfo);
        votingManager.submitDepositInfo(user, depositAmount, chainId, txInfo, extraInfo, signature);
        depositInfo = depositManager.getDeposit(user, depositIndex);
        assertEq(
            encodedParams,
            abi.encodePacked(
                depositInfo.targetAddress,
                depositInfo.amount,
                depositInfo.chainId,
                depositInfo.txInfo,
                depositInfo.extraInfo
            )
        );
        vm.stopPrank();
    }

    function testFuzz_DepositFuzz(address _user, uint256 _amount, bytes memory _txInfo) public {
        // setup deposit info
        uint256 depositIndex = depositManager.getDeposits(user).length;
        uint256 chainId = 0;
        bytes memory extraInfo = "--- extra info ---";
        bytes memory encodedParams = abi.encodePacked(_user, _amount, chainId, _txInfo, extraInfo);
        bytes memory signature = generateSignature(encodedParams, privKey);

        // check event and result
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit IDepositManager.DepositRecorded(_user, _amount, chainId, _txInfo, extraInfo);
        votingManager.submitDepositInfo(_user, _amount, chainId, _txInfo, extraInfo, signature);
        IDepositManager.DepositInfo memory depositInfo = depositManager.getDeposit(
            _user,
            depositIndex
        );
        assertEq(
            encodedParams,
            abi.encodePacked(
                depositInfo.targetAddress,
                depositInfo.amount,
                depositInfo.chainId,
                depositInfo.txInfo,
                depositInfo.extraInfo
            )
        );
    }
}
