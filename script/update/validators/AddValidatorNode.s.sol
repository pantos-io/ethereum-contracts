// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {AccessController} from "../../../src/access/AccessController.sol";
import {PantosForwarder} from "../../../src/PantosForwarder.sol";

import {PantosBaseAddresses} from "./../../helpers/PantosBaseAddresses.s.sol";
import {SafeAddresses} from "./../../helpers/SafeAddresses.s.sol";

/**
 * @title AddValidatorNode
 *
 * @notice Add a validator node to the Pantos Forwarder.
 *
 * @dev Usage
 * 1. Add a new validator node
 * forge script ./script/update/validators/AddValidatorNode.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(address,address,address)" <newValidatorNode> \
 *      <accessControllerAddress>  <pantosForwarder>
 * 2. Add a new validator node and change the minimum threshold of validator nodes.
 * forge script ./script/update/validators/AddValidatorNode.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(address,address,address)" <newValidatorNode> \
 *      <newMinimumThreshold> <accessControllerAddress>  <pantosForwarder>
 */
contract AddValidatorNode is PantosBaseAddresses, SafeAddresses {
    AccessController accessController;
    PantosForwarder public pantosForwarder;

    function roleActions(
        address newValidatorNode,
        address accessController_,
        address pantosForwarder_
    ) public {
        accessController = AccessController(accessController_);
        pantosForwarder = PantosForwarder(pantosForwarder_);

        address[] memory validatorNodes = pantosForwarder.getValidatorNodes();
        for (uint256 i = 0; i < validatorNodes.length; i++) {
            require(
                validatorNodes[i] != newValidatorNode,
                "Validator node already exists"
            );
        }
        vm.broadcast(accessController.pauser());
        pantosForwarder.pause();
        console.log("Pantos forwarder paused: %s", pantosForwarder.paused());

        vm.startBroadcast(accessController.superCriticalOps());
        pantosForwarder.addValidatorNode(newValidatorNode);
        pantosForwarder.unpause();
        console.log("Validator node %s added", newValidatorNode);
        console.log("Pantos forwarder paused: %s", pantosForwarder.paused());
        vm.stopBroadcast();

        writeAllSafeInfo(accessController);
    }

    function roleActions(
        address newValidatorNode,
        uint256 newMinimumThreshold,
        address accessController_,
        address pantosForwarder_
    ) public {
        accessController = AccessController(accessController_);
        pantosForwarder = PantosForwarder(pantosForwarder_);

        require(
            newMinimumThreshold > 0,
            "Minimum threshold must be greater than 0"
        );
        address[] memory validatorNodes = pantosForwarder.getValidatorNodes();
        for (uint256 i = 0; i < validatorNodes.length; i++) {
            require(
                validatorNodes[i] != newValidatorNode,
                "Validator node already exists"
            );
        }
        vm.broadcast(accessController.pauser());
        pantosForwarder.pause();
        console.log("Pantos forwarder paused: %s", pantosForwarder.paused());

        vm.startBroadcast(accessController.superCriticalOps());
        pantosForwarder.setMinimumValidatorNodeSignatures(newMinimumThreshold);
        pantosForwarder.addValidatorNode(newValidatorNode);
        pantosForwarder.unpause();
        console.log("Validator node %s added", newValidatorNode);
        console.log("New minimum threshold: %s", newMinimumThreshold);
        console.log("Pantos forwarder paused: %s", pantosForwarder.paused());
        vm.stopBroadcast();

        writeAllSafeInfo(accessController);
    }
}
