// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/

import "forge-std/console2.sol";

import "../src/PantosCoinWrapper.sol";

import "./PantosBaseTest.t.sol";

contract PantosCoinWrapperTest is PantosBaseTest {
    PantosCoinWrapper pantosCoinWrapper;
    address constant PANTOS_FORWARDER_ADDRESS =
        address(uint160(uint256(keccak256("PantosForwarderAddress"))));
    uint256 constant WRAPPED_AMOUNT = 1000;
    string constant NAME = "test token";
    string constant SYMBOL = "TEST";
    uint8 constant DECIMALS = 18;

    function setUp() public {
        pantosCoinWrapper = new PantosCoinWrapper(
            NAME,
            SYMBOL,
            DECIMALS,
            true
        );
    }

    function test_wrap() external {
        initializePantosCoinWrapper();
        uint256 initialBalance = deployer().balance;
        vm.expectEmit();
        emit IERC20.Transfer(ADDRESS_ZERO, deployer(), WRAPPED_AMOUNT);

        pantosCoinWrapper.wrap{value: WRAPPED_AMOUNT}();

        assertEq(pantosCoinWrapper.balanceOf(deployer()), WRAPPED_AMOUNT);
        assertEq(deployer().balance, initialBalance - WRAPPED_AMOUNT);
    }

    function test_wrap_WhenPaused() external {
        pantosCoinWrapper.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosWrapper.pause.selector
        );

        whenNotPausedTest(address(pantosCoinWrapper), calldata_);
    }

    function test_wrap_WhenNotNative() external {
        PantosCoinWrapper pantosCoinWrapper_ = new PantosCoinWrapper(
            NAME,
            SYMBOL,
            DECIMALS,
            false
        );
        pantosCoinWrapper_.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        pantosCoinWrapper_.unpause();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosCoinWrapper.wrap.selector
        );

        onlyNativeTest(address(pantosCoinWrapper_), calldata_);
    }

    function test_unwrap() external {
        wrap(WRAPPED_AMOUNT);
        uint256 initialBalance = deployer().balance;
        vm.expectEmit();
        emit IERC20.Transfer(deployer(), ADDRESS_ZERO, WRAPPED_AMOUNT);

        pantosCoinWrapper.unwrap(WRAPPED_AMOUNT);

        assertEq(pantosCoinWrapper.balanceOf(deployer()), 0);
        assertEq(deployer().balance, initialBalance + WRAPPED_AMOUNT);
    }

    function test_unwrap_WhenPaused() external {
        pantosCoinWrapper.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosWrapper.pause.selector
        );

        whenNotPausedTest(address(pantosCoinWrapper), calldata_);
    }

    function test_unwrap_WhenNotNative() external {
        PantosCoinWrapper pantosCoinWrapper_ = new PantosCoinWrapper(
            NAME,
            SYMBOL,
            DECIMALS,
            false
        );
        pantosCoinWrapper_.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        pantosCoinWrapper_.unpause();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosCoinWrapper.wrap.selector
        );

        onlyNativeTest(address(pantosCoinWrapper_), calldata_);
    }

    function wrap(uint256 amount) public {
        initializePantosCoinWrapper();
        pantosCoinWrapper.wrap{value: amount}();
    }

    function initializePantosCoinWrapper() public {
        pantosCoinWrapper.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        pantosCoinWrapper.unpause();
    }

    // necessary to be able to receive native coins when calling unwrap
    receive() external payable {}
}
