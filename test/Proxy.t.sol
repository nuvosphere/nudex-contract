pragma solidity ^0.8.0;

import "./BaseTest.sol";

import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {NuvoProxy, ProxyAdmin} from "../src/proxies/NuvoProxy.sol";
import "../src/mocks/MockLogic.sol";

contract CustomProxy is BaseTest {
    MockLogic1 logic1;
    MockLogic2 logic2;
    ProxyAdmin proxyAdmin;

    function setUp() public override {
        super.setUp();

        logic1 = new MockLogic1();
        logic2 = new MockLogic2();
        proxyAdmin = new ProxyAdmin(msgSender);
    }

    function test_Upgrade() public {
        vm.startPrank(msgSender);
        // setup as logic1
        NuvoProxy proxy = new NuvoProxy(address(logic1), address(proxyAdmin));
        assertEq(proxy.admin(), address(proxyAdmin));
        MockLogic1 proxyLogic = MockLogic1(address(proxy));
        assertEq(proxyLogic.v(), logic1.v());
        assertEq(proxyLogic.show(), logic1.show());

        // func2() does not exit in logic1 contract
        MockLogic2 proxyLogic2 = MockLogic2(address(proxy));
        vm.expectRevert();
        proxyLogic2.func2();

        // upgrade to logic2
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)),
            address(logic2),
            ""
        );
        assertEq(proxyLogic.v(), logic2.v());
        assertEq(proxyLogic.show(), logic2.show());
        vm.stopPrank();
    }

    function test_SelfUpgrade() public {
        vm.startPrank(msgSender);
        // setup as logic1
        MockSelfUpgrade logic = new MockSelfUpgrade();
        NuvoProxy proxy = new NuvoProxy(address(logic), address(0));
        assertEq(proxy.admin(), address(proxy));
        MockSelfUpgrade proxyLogic = MockSelfUpgrade(address(proxy));
        assertEq(proxyLogic.v(), logic.v());

        // func2() does not exit in logic1 contract
        MockLogic2 proxyLogic2 = MockLogic2(address(proxy));
        vm.expectRevert();
        proxyLogic2.func2();

        // upgrade to logic2 through upgrade()
        proxyLogic.upgrade(address(logic2), "");
        assertEq(proxyLogic.v(), logic2.v());
        vm.stopPrank();
    }
}
