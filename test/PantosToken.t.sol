// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {console2} from "forge-std/console2.sol";

import {IPantosToken} from "../src/interfaces/IPantosToken.sol";
import {PantosBaseToken} from "../src/PantosBaseToken.sol";
import {PantosToken} from "../src/PantosToken.sol";

import {PantosBaseTokenTest} from "./PantosBaseToken.t.sol";

contract PantosTokenTest is PantosBaseTokenTest {
    PantosTokenHarness public pantosToken;

    function setUp() public {
        accessController = deployAccessController();
        pantosToken = new PantosTokenHarness(
            INITIAL_SUPPLY_PAN,
            address(accessController)
        );
    }

    function test_SetUpState() external {
        assertEq(
            pantosToken.balanceOf(SUPER_CRITICAL_OPS),
            INITIAL_SUPPLY_PAN
        );
        assertTrue(pantosToken.paused());
        assertEq(pantosToken.getOwner(), SUPER_CRITICAL_OPS);
    }

    function test_pause_AfterInitialization() external {
        initializeToken();

        vm.prank(PAUSER);
        pantosToken.pause();

        assertTrue(pantosToken.paused());
    }

    function test_pause_WhenPaused() external {
        vm.prank(SUPER_CRITICAL_OPS);
        pantosToken.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosToken.pause.selector
        );

        whenNotPausedTest(address(pantosToken), calldata_);
    }

    function test_pause_ByNonPauser() external {
        initializeToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosToken.pause.selector
        );

        onlyRoleTest(address(pantosToken), calldata_);
    }

    function test_unpause_AfterDeploy() external {
        initializeToken();

        assertFalse(pantosToken.paused());
    }

    function test_unpause_WhenNotpaused() external {
        initializeToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosToken.unpause.selector
        );

        whenPausedTest(address(pantosToken), calldata_);
    }

    function test_unpause_ByNonSuperCriticalOps() external {
        vm.prank(SUPER_CRITICAL_OPS);
        pantosToken.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosToken.unpause.selector
        );

        onlyRoleTest(address(pantosToken), calldata_);
    }

    function test_unpause_WithNoForwarderSet() external {
        vm.expectRevert(
            abi.encodePacked("PantosToken: PantosForwarder has not been set")
        );

        vm.prank(SUPER_CRITICAL_OPS);
        pantosToken.unpause();
    }

    function test_setPantosForwarder() external {
        initializeToken();

        assertEq(pantosToken.getPantosForwarder(), PANTOS_FORWARDER_ADDRESS);
    }

    function test_setPantosForwarder_WhenNotpaused() external {
        initializeToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosToken.setPantosForwarder.selector,
            PANTOS_FORWARDER_ADDRESS
        );

        whenPausedTest(address(pantosToken), calldata_);
    }

    function test_setPantosForwarder_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosToken.setPantosForwarder.selector,
            PANTOS_FORWARDER_ADDRESS
        );

        onlyOwnerTest(address(pantosToken), calldata_);
    }

    function test_decimals() external {
        assertEq(8, pantosToken.decimals());
    }

    function test_symbol() external {
        assertEq("PAN", pantosToken.symbol());
    }

    function test_name() external {
        assertEq("Pantos", pantosToken.name());
    }

    function test_getOwner() external {
        assertEq(token().getOwner(), SUPER_CRITICAL_OPS);
    }

    function test_renounceOwnership() external {
        vm.prank(SUPER_CRITICAL_OPS);
        pantosToken.renounceOwnership();

        assertEq(pantosToken.getOwner(), address(0));
    }

    function test_transferOwnership() external {
        vm.expectRevert(
            abi.encodePacked("PantosToken: ownership cannot be transferred")
        );

        vm.prank(SUPER_CRITICAL_OPS);
        pantosToken.transferOwnership(address(1));

        assertEq(pantosToken.getOwner(), SUPER_CRITICAL_OPS);
    }

    function test_unsetPantosForwarder() external {
        initializeToken();
        vm.expectEmit();
        emit IPantosToken.PantosForwarderUnset();

        vm.prank(SUPER_CRITICAL_OPS);
        pantosToken.exposed_unsetPantosForwarder();

        assertEq(pantosToken.getPantosForwarder(), ADDRESS_ZERO);
    }

    function initializeToken() public override {
        vm.startPrank(SUPER_CRITICAL_OPS);
        pantosToken.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        pantosToken.unpause();
        vm.stopPrank();
    }

    function token() public view override returns (PantosBaseToken) {
        return pantosToken;
    }

    function tokenRevertMsgPrefix()
        public
        pure
        override
        returns (string memory)
    {
        return "PantosToken:";
    }
}

contract PantosTokenHarness is PantosToken {
    constructor(
        uint256 initialSupply,
        address accessController
    ) PantosToken(initialSupply, accessController) {}

    function exposed_unsetPantosForwarder() external {
        _unsetPantosForwarder();
    }
}
