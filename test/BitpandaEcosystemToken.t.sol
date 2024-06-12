// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/

import "forge-std/console2.sol";

import "../src/BitpandaEcosystemToken.sol";

import "./PantosBaseToken.t.sol";

contract BitpandaEcosystemTokenTest is PantosBaseTokenTest {
    BitpandaEcosystemTokenHarness bestToken;

    function setUp() public {
        bestToken = new BitpandaEcosystemTokenHarness(INITIAL_SUPPLY_BEST);
    }

    function test_SetUpState() external {
        assertEq(bestToken.balanceOf(deployer()), INITIAL_SUPPLY_BEST);
        assertTrue(bestToken.paused());
        assertEq(bestToken.getOwner(), deployer());
    }

    function test_pause_AfterInitialization() external {
        initializeToken();

        bestToken.pause();

        assertTrue(bestToken.paused());
    }

    function test_pause_WhenPaused() external {
        bestToken.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            bestToken.pause.selector
        );

        whenNotPausedTest(address(bestToken), calldata_);
    }

    function test_pause_ByNonOwner() external {
        initializeToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            bestToken.pause.selector
        );

        onlyOwnerTest(address(bestToken), calldata_);
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

    function test_unpause_ByNonOwner() external {
        bestToken.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            bestToken.unpause.selector
        );

        onlyOwnerTest(address(bestToken), calldata_);
    }

    function test_unpause_WithNoForwarderSet() external {
        vm.expectRevert(
            abi.encodePacked(
                "BitpandaEcosystemToken: PantosForwarder has not been set"
            )
        );

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

    function test_unsetPantosForwarder() external {
        initializeToken();
        vm.expectEmit();
        emit IPantosToken.PantosForwarderUnset();

        bestToken.exposed_unsetPantosForwarder();

        assertEq(bestToken.getPantosForwarder(), ADDRESS_ZERO);
    }

    function initializeToken() public override {
        bestToken.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        bestToken.unpause();
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
    constructor(uint256 initialSupply) BitpandaEcosystemToken(initialSupply) {}

    function exposed_unsetPantosForwarder() external {
        _unsetPantosForwarder();
    }
}
