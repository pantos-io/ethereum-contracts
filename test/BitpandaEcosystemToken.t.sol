// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {console2} from "forge-std/console2.sol";

import {IPantosToken} from "../src/interfaces/IPantosToken.sol";
import {PantosBaseToken} from "../src/PantosBaseToken.sol";
import {BitpandaEcosystemToken} from "../src/BitpandaEcosystemToken.sol";

import {PantosBaseTokenTest} from "./PantosBaseToken.t.sol";

contract BitpandaEcosystemTokenTest is PantosBaseTokenTest {
    BitpandaEcosystemTokenHarness bestToken;

    function setUp() public {
        accessController = deployAccessController();
        bestToken = new BitpandaEcosystemTokenHarness(
            INITIAL_SUPPLY_BEST,
            address(accessController)
        );
    }

    function test_SetUpState() external {
        assertEq(bestToken.balanceOf(SUPER_CRITICAL_OPS), INITIAL_SUPPLY_BEST);
        assertTrue(bestToken.paused());
        assertEq(bestToken.getOwner(), SUPER_CRITICAL_OPS);
    }

    function test_pause_AfterInitialization() external {
        initializeToken();

        vm.prank(PAUSER);
        bestToken.pause();

        assertTrue(bestToken.paused());
    }

    function test_pause_WhenPaused() external {
        vm.prank(SUPER_CRITICAL_OPS);
        bestToken.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            bestToken.pause.selector
        );

        whenNotPausedTest(address(bestToken), calldata_);
    }

    function test_pause_ByNonPauser() external {
        initializeToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            bestToken.pause.selector
        );

        onlyRoleTest(address(bestToken), calldata_);
    }

    function test_unpause_AfterDeploy() external {
        initializeToken();

        assertFalse(bestToken.paused());
    }

    function test_unpause_WhenNotpaused() external {
        initializeToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            bestToken.unpause.selector
        );

        whenPausedTest(address(bestToken), calldata_);
    }

    function test_unpause_ByNonSuperCriticalOps() external {
        vm.prank(SUPER_CRITICAL_OPS);
        bestToken.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            bestToken.unpause.selector
        );

        onlyRoleTest(address(bestToken), calldata_);
    }

    function test_unpause_WithNoForwarderSet() external {
        vm.expectRevert(
            abi.encodePacked(
                "BitpandaEcosystemToken: PantosForwarder has not been set"
            )
        );

        vm.prank(SUPER_CRITICAL_OPS);
        bestToken.unpause();
    }

    function test_setPantosForwarder() external {
        initializeToken();

        assertEq(bestToken.getPantosForwarder(), PANTOS_FORWARDER_ADDRESS);
    }

    function test_setPantosForwarder_WhenNotpaused() external {
        initializeToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            bestToken.setPantosForwarder.selector,
            PANTOS_FORWARDER_ADDRESS
        );

        whenPausedTest(address(bestToken), calldata_);
    }

    function test_setPantosForwarder_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            bestToken.setPantosForwarder.selector,
            PANTOS_FORWARDER_ADDRESS
        );

        onlyOwnerTest(address(bestToken), calldata_);
    }

    function test_decimals() external {
        assertEq(8, bestToken.decimals());
    }

    function test_symbol() external {
        assertEq("BEST", bestToken.symbol());
    }

    function test_name() external {
        assertEq("Bitpanda Ecosystem Token", bestToken.name());
    }

    function test_getOwner() external {
        assertEq(token().getOwner(), SUPER_CRITICAL_OPS);
    }

    function test_renounceOwnership() external {
        vm.prank(SUPER_CRITICAL_OPS);
        bestToken.renounceOwnership();

        assertEq(bestToken.getOwner(), address(0));
    }

    function test_transferOwnership() external {
        vm.expectRevert(
            abi.encodePacked(
                "BitpandaEcosystemToken: ownership cannot be transferred"
            )
        );
        vm.prank(SUPER_CRITICAL_OPS);
        bestToken.transferOwnership(address(1));

        assertEq(bestToken.getOwner(), SUPER_CRITICAL_OPS);
    }

    function test_unsetPantosForwarder() external {
        initializeToken();
        vm.expectEmit();
        emit IPantosToken.PantosForwarderUnset();

        vm.prank(SUPER_CRITICAL_OPS);
        bestToken.exposed_unsetPantosForwarder();

        assertEq(bestToken.getPantosForwarder(), ADDRESS_ZERO);
    }

    function initializeToken() public override {
        vm.startPrank(SUPER_CRITICAL_OPS);
        bestToken.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        bestToken.unpause();
        vm.stopPrank();
    }

    function token() public view override returns (PantosBaseToken) {
        return bestToken;
    }

    function tokenRevertMsgPrefix()
        public
        pure
        override
        returns (string memory)
    {
        return "BitpandaEcosystemToken:";
    }
}

contract BitpandaEcosystemTokenHarness is BitpandaEcosystemToken {
    constructor(
        uint256 initialSupply,
        address accessController
    ) BitpandaEcosystemToken(initialSupply, accessController) {}

    function exposed_unsetPantosForwarder() external {
        _unsetPantosForwarder();
    }
}
