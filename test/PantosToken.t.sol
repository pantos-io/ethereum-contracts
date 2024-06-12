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
        pantosToken = new PantosTokenHarness(INITIAL_SUPPLY_PAN);
    }

    function test_SetUpState() external {
        assertEq(pantosToken.balanceOf(deployer()), INITIAL_SUPPLY_PAN);
        assertTrue(pantosToken.paused());
        assertEq(pantosToken.getOwner(), deployer());
    }

    function test_pause_AfterInitialization() external {
        initializeToken();

        pantosToken.pause();

        assertTrue(pantosToken.paused());
    }

    function test_pause_WhenPaused() external {
        pantosToken.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosToken.pause.selector
        );

        whenNotPausedTest(address(pantosToken), calldata_);
    }

    function test_pause_ByNonOwner() external {
        initializeToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosToken.pause.selector
        );

        onlyOwnerTest(address(pantosToken), calldata_);
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

    function test_unpause_ByNonOwner() external {
        pantosToken.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosToken.unpause.selector
        );

        onlyOwnerTest(address(pantosToken), calldata_);
    }

    function test_unpause_WithNoForwarderSet() external {
        vm.expectRevert(
            abi.encodePacked("PantosToken: PantosForwarder has not been set")
        );

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

    function test_unsetPantosForwarder() external {
        initializeToken();
        vm.expectEmit();
        emit IPantosToken.PantosForwarderUnset();

        pantosToken.exposed_unsetPantosForwarder();

        assertEq(pantosToken.getPantosForwarder(), ADDRESS_ZERO);
    }

    function initializeToken() public override {
        pantosToken.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        pantosToken.unpause();
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
    constructor(uint256 initialSupply) PantosToken(initialSupply) {}

    function exposed_unsetPantosForwarder() external {
        _unsetPantosForwarder();
    }
}
