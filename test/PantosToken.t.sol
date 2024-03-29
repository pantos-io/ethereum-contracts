// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

/* solhint-disable no-console*/

import "forge-std/console2.sol";

import "../src/contracts/PantosToken.sol";

import "./PantosBaseTest.t.sol";

contract PantosTokenTest is PantosBaseTest {
    PantosTokenHarness public pantosToken;
    address public pantosForwarderAddress =
        address(uint160(uint256(keccak256("PantosForwarderAddress"))));

    function setUp() public {
        pantosToken = new PantosTokenHarness(INITIAL_SUPPLY_PAN);
    }

    function test_SetUpState() external {
        assertEq(pantosToken.balanceOf(deployer()), INITIAL_SUPPLY_PAN);
        assertTrue(pantosToken.paused());
        assertEq(pantosToken.getOwner(), deployer());
    }

    function test_pause_AfterInitialization() external {
        initializePantosToken();

        pantosToken.pause();

        assertTrue(pantosToken.paused());
    }

    function test_pause_WhenPaused() external {
        pantosToken.setPantosForwarder(pantosForwarderAddress);
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosToken.pause.selector
        );

        whenNotPausedTest(address(pantosToken), calldata_);
    }

    function test_pause_ByNonOwner() external {
        initializePantosToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosToken.pause.selector
        );

        onlyOwnerTest(address(pantosToken), calldata_);
    }

    function test_unpause_AfterDeploy() external {
        initializePantosToken();

        assertFalse(pantosToken.paused());
    }

    function test_unpause_WhenNotpaused() external {
        initializePantosToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosToken.unpause.selector
        );

        whenPausedTest(address(pantosToken), calldata_);
    }

    function test_unpause_ByNonOwner() external {
        pantosToken.setPantosForwarder(pantosForwarderAddress);
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
        initializePantosToken();

        assertEq(pantosToken.getPantosForwarder(), pantosForwarderAddress);
    }

    function test_setPantosForwarder_WhenNotpaused() external {
        initializePantosToken();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosToken.setPantosForwarder.selector,
            pantosForwarderAddress
        );

        whenPausedTest(address(pantosToken), calldata_);
    }

    function test_setPantosForwarder_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosToken.setPantosForwarder.selector,
            pantosForwarderAddress
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

    function test_pantosTransferTo() external {
        initializePantosToken();
        address receiver = address(2);
        uint256 amount = 1_000;
        uint256 receiverBalanceBefore = pantosToken.balanceOf(receiver);

        vm.prank(pantosForwarderAddress);
        pantosToken.pantosTransferTo(receiver, amount);

        uint256 receiverBalanceAfter = pantosToken.balanceOf(receiver);
        assertEq(receiverBalanceBefore + amount, receiverBalanceAfter);
    }

    function test_pantosTransferFrom() external {
        initializePantosToken();
        address sender = address(1);
        uint256 amount = 1_000_000;
        // topup sender balance
        vm.prank(pantosForwarderAddress);
        pantosToken.pantosTransferTo(sender, amount);
        uint256 senderBalanceBefore = pantosToken.balanceOf(sender);

        vm.prank(pantosForwarderAddress);
        pantosToken.pantosTransferFrom(sender, amount);

        uint256 senderBalanceAfter = pantosToken.balanceOf(sender);
        assertEq(senderBalanceBefore - amount, senderBalanceAfter);
    }

    function test_pantosTransfer() external {
        initializePantosToken();
        address sender = address(1);
        address receiver = address(2);
        uint256 amount = 1_000_000;
        // topup sender balance
        vm.prank(pantosForwarderAddress);
        pantosToken.pantosTransferTo(sender, amount);
        uint256 senderBalanceBefore = pantosToken.balanceOf(sender);
        uint256 receiverBalanceBefore = pantosToken.balanceOf(receiver);

        vm.prank(pantosForwarderAddress);
        pantosToken.pantosTransfer(sender, receiver, amount);

        uint256 receiverBalanceAfter = pantosToken.balanceOf(receiver);
        uint256 senderBalanceAfter = pantosToken.balanceOf(sender);
        assertEq(receiverBalanceBefore + amount, receiverBalanceAfter);
        assertEq(senderBalanceBefore - amount, senderBalanceAfter);
    }

    function test_unsetPantosForwarder() external {
        initializePantosToken();
        vm.expectEmit();
        emit IPantosToken.PantosForwarderUnset();

        pantosToken.exposed_unsetPantosForwarder();

        assertEq(pantosToken.getPantosForwarder(), ADDRESS_ZERO);
    }

    function test_getOwner() external {
        initializePantosToken();

        assertEq(pantosToken.getOwner(), deployer());
    }

    function initializePantosToken() public {
        pantosToken.setPantosForwarder(pantosForwarderAddress);
        pantosToken.unpause();
    }
}

contract PantosTokenHarness is PantosToken {
    constructor(uint256 initialSupply) PantosToken(initialSupply) {}

    function exposed_unsetPantosForwarder() external {
        _unsetPantosForwarder();
    }
}
