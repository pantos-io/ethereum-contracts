// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {AccessController} from "../../../src/access/AccessController.sol";
import {IPantosHub} from "../../../src/interfaces/IPantosHub.sol";

import {PantosBaseAddresses} from "./../../helpers/PantosBaseAddresses.s.sol";
import {SafeAddresses} from "./../../helpers/SafeAddresses.s.sol";

/**
 * @title SetPrimaryValidatorNode
 *
 * @notice Set the primary validator node at the Pantos Hub.
 *
 * @dev Usage
 * forge script ./script/update/parameters/SetPrimaryValidatorNode.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(address)" <newPirmaryValidatorNode>
 */
contract SetPrimaryValidatorNode is PantosBaseAddresses, SafeAddresses {
    AccessController accessController;
    IPantosHub public pantosHub;

    function roleActions(address newPirmaryValidatorNode) public {
        readContractAddresses(determineBlockchain());
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        pantosHub = IPantosHub(getContractAddress(Contract.HUB_PROXY, false));

        address oldPrimaryValidatorNode = pantosHub.getPrimaryValidatorNode();
        if (oldPrimaryValidatorNode == newPirmaryValidatorNode) {
            console.log(
                "Primary validator node is already set to %s",
                newPirmaryValidatorNode
            );
            revert("Primary validator node is already set to the new value");
        }

        vm.broadcast(accessController.pauser());
        pantosHub.pause();
        console.log("Pantos hub paused: %s", pantosHub.paused());

        vm.startBroadcast(accessController.superCriticalOps());
        pantosHub.setPrimaryValidatorNode(newPirmaryValidatorNode);
        pantosHub.unpause();
        console.log(
            "Primary validator node set to %s, old value was %s",
            newPirmaryValidatorNode,
            oldPrimaryValidatorNode
        );
        console.log("Pantos hub paused: %s", pantosHub.paused());
        vm.stopBroadcast();

        writeAllSafeInfo(accessController);
    }
}
