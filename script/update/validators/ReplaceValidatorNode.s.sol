// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {AccessController} from "../../../src/access/AccessController.sol";
import {PantosForwarder} from "../../../src/PantosForwarder.sol";

import {PantosBaseAddresses} from "./../../helpers/PantosBaseAddresses.s.sol";
import {SafeAddresses} from "./../../helpers/SafeAddresses.s.sol";

/**
 * @title ReplaceValidatorNode
 *
 * @notice Replace a validator node at the Pantos Forwarder.
 *
 * @dev Usage
 * forge script ./script/update/validators/ReplaceValidatorNode.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(address,address)" <oldValidatorNode> <newValidatorNode>
 */
contract ReplaceValidatorNode is PantosBaseAddresses, SafeAddresses {
    AccessController accessController;
    PantosForwarder public pantosForwarder;

    function roleActions(
        address oldValidatorNode,
        address newValidatorNode
    ) public {
        readContractAddresses(determineBlockchain());
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        pantosForwarder = PantosForwarder(
            getContractAddress(Contract.FORWARDER, false)
        );

        address[] memory validatorNodes = pantosForwarder.getValidatorNodes();
        bool found = false;
        for (uint256 i = 0; i < validatorNodes.length; i++) {
            require(
                validatorNodes[i] != newValidatorNode,
                "New validator node already exists"
            );
            if (validatorNodes[i] == oldValidatorNode) {
                found = true;
                break;
            }
        }
        if (!found) {
            console.log("Old validator node %s not found", oldValidatorNode);
            revert("Validator node not found");
        }
        vm.broadcast(accessController.pauser());
        pantosForwarder.pause();
        console.log("Pantos forwarder paused: %s", pantosForwarder.paused());

        vm.startBroadcast(accessController.superCriticalOps());
        pantosForwarder.addValidatorNode(newValidatorNode);
        pantosForwarder.removeValidatorNode(oldValidatorNode);
        pantosForwarder.unpause();
        console.log("Validator node %s added", newValidatorNode);
        console.log("Old validator node %s removed", oldValidatorNode);
        console.log("Pantos forwarder paused: %s", pantosForwarder.paused());
        vm.stopBroadcast();

        writeAllSafeInfo(accessController);
    }
}
