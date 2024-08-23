// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {console2} from "forge-std/console2.sol";

import {PantosBaseToken} from "../src/PantosBaseToken.sol";
import {BitpandaEcosystemToken} from "../src/BitpandaEcosystemToken.sol";
import {AccessController} from "../src/access/AccessController.sol";

import {PantosBaseTest} from "./PantosBaseTest.t.sol";

abstract contract PantosBaseTokenTest is PantosBaseTest {
    address public constant PANTOS_FORWARDER_ADDRESS =
        address(uint160(uint256(keccak256("PantosForwarderAddress"))));

    AccessController public accessController;

    function initializeToken() public virtual;

    function token() public view virtual returns (PantosBaseToken);

    function tokenRevertMsgPrefix()
        public
        pure
        virtual
        returns (string memory);

    function test_pantosTransferTo() external {
        initializeToken();
        address receiver = address(2);
        uint256 amount = 1_000;
        uint256 receiverBalanceBefore = token().balanceOf(receiver);
        vm.expectEmit();
        emit IERC20.Transfer(ADDRESS_ZERO, receiver, amount);

        vm.prank(PANTOS_FORWARDER_ADDRESS);
        token().pantosTransferTo(receiver, amount);

        uint256 receiverBalanceAfter = token().balanceOf(receiver);
        assertEq(receiverBalanceBefore + amount, receiverBalanceAfter);
    }

    function test_pantosTransferTo_NotByPantosForwarder() external {
        initializeToken();
        address receiver = address(2);
        uint256 amount = 1_000;

        string memory revertMsg = string.concat(
            tokenRevertMsgPrefix(),
            " caller is not the PantosForwarder"
        );
        vm.expectRevert(bytes(revertMsg));
        token().pantosTransferTo(receiver, amount);
    }

    function test_pantosTransferTo_RecieverAddress0() external {
        initializeToken();
        address receiver = address(0);
        uint256 amount = 1_000;

        bytes4 selector = IERC20Errors.ERC20InvalidReceiver.selector;
        bytes memory revertMessage = abi.encodeWithSelector(
            selector,
            ADDRESS_ZERO
        );
        vm.expectRevert(revertMessage);
        vm.prank(PANTOS_FORWARDER_ADDRESS);

        token().pantosTransferTo(receiver, amount);
    }

    function test_pantosTransferFrom() external {
        initializeToken();
        address sender = address(1);
        uint256 amount = 1_000_000;
        // topup sender balance
        vm.prank(PANTOS_FORWARDER_ADDRESS);
        token().pantosTransferTo(sender, amount);
        uint256 senderBalanceBefore = token().balanceOf(sender);
        vm.expectEmit();
        emit IERC20.Transfer(sender, ADDRESS_ZERO, amount);

        vm.prank(PANTOS_FORWARDER_ADDRESS);
        token().pantosTransferFrom(sender, amount);

        uint256 senderBalanceAfter = token().balanceOf(sender);
        assertEq(senderBalanceBefore - amount, senderBalanceAfter);
    }

    function test_pantosTransferFrom_NotByPantosForwarder() external {
        initializeToken();
        address sender = address(1);
        uint256 amount = 1_000_000;
        string memory revertMsg = string.concat(
            tokenRevertMsgPrefix(),
            " caller is not the PantosForwarder"
        );
        vm.expectRevert(bytes(revertMsg));

        token().pantosTransferFrom(sender, amount);
    }

    function test_pantosTransferFrom_SenderAddress0() external {
        initializeToken();
        address sender = ADDRESS_ZERO;
        uint256 amount = 1_000_000;

        bytes4 selector = IERC20Errors.ERC20InvalidSender.selector;
        bytes memory revertMessage = abi.encodeWithSelector(
            selector,
            ADDRESS_ZERO
        );
        vm.expectRevert(revertMessage);
        vm.prank(PANTOS_FORWARDER_ADDRESS);

        token().pantosTransferFrom(sender, amount);
    }

    function test_pantosTransfer() external {
        initializeToken();
        address sender = address(1);
        address receiver = address(2);
        uint256 amount = 1_000_000;
        // topup sender balance
        vm.prank(PANTOS_FORWARDER_ADDRESS);
        token().pantosTransferTo(sender, amount);
        uint256 senderBalanceBefore = token().balanceOf(sender);
        uint256 receiverBalanceBefore = token().balanceOf(receiver);
        vm.expectEmit();
        emit IERC20.Transfer(sender, receiver, amount);

        vm.prank(PANTOS_FORWARDER_ADDRESS);
        token().pantosTransfer(sender, receiver, amount);

        uint256 receiverBalanceAfter = token().balanceOf(receiver);
        uint256 senderBalanceAfter = token().balanceOf(sender);
        assertEq(receiverBalanceBefore + amount, receiverBalanceAfter);
        assertEq(senderBalanceBefore - amount, senderBalanceAfter);
    }

    function test_pantosTransfer_NotByPantosForwarder() external {
        initializeToken();
        address sender = address(1);
        address receiver = address(2);
        uint256 amount = 1_000_000;

        string memory revertMsg = string.concat(
            tokenRevertMsgPrefix(),
            " caller is not the PantosForwarder"
        );
        vm.expectRevert(bytes(revertMsg));

        token().pantosTransfer(sender, receiver, amount);
    }

    function test_pantosTransfer_SenderAddress0() external {
        initializeToken();
        address sender = ADDRESS_ZERO;
        address receiver = address(2);
        uint256 amount = 1_000_000;
        bytes4 selector = IERC20Errors.ERC20InvalidSender.selector;
        bytes memory revertMessage = abi.encodeWithSelector(
            selector,
            ADDRESS_ZERO
        );
        vm.expectRevert(revertMessage);
        vm.prank(PANTOS_FORWARDER_ADDRESS);

        token().pantosTransfer(sender, receiver, amount);
    }

    function test_pantosTransfer_RecieverAddress0() external {
        initializeToken();
        address sender = address(1);
        address receiver = ADDRESS_ZERO;
        uint256 amount = 1_000_000;
        bytes4 selector = IERC20Errors.ERC20InvalidReceiver.selector;
        bytes memory revertMessage = abi.encodeWithSelector(
            selector,
            ADDRESS_ZERO
        );
        vm.expectRevert(revertMessage);
        vm.prank(PANTOS_FORWARDER_ADDRESS);

        token().pantosTransfer(sender, receiver, amount);
    }

    function test_getOwner() external {
        initializeToken();

        assertEq(token().getOwner(), deployer());
    }
}
