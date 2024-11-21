// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {AccessController} from "../../../src/access/AccessController.sol";
import {PantosForwarder} from "../../../src/PantosForwarder.sol";

import {PantosBaseAddresses} from "./../../helpers/PantosBaseAddresses.s.sol";
import {SafeAddresses} from "./../../helpers/SafeAddresses.s.sol";

/**
 * @title SetMinValidatorNodeSignatures
 *
 * @notice Set the minimum number of required validator node signatures.
 *
 * @dev Usage
 * forge script ./script/update/parameters/SetMinValidatorNodeSignatures.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(uint256)" <newMinimumThreshold>
 */
contract SetMinValidatorNodeSignatures is PantosBaseAddresses, SafeAddresses {
    AccessController accessController;
    PantosForwarder public pantosForwarder;

    function roleActions(uint256 newMinimumThreshold) public {
        readContractAddresses(determineBlockchain());
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        pantosForwarder = PantosForwarder(
            getContractAddress(Contract.FORWARDER, false)
        );

        require(
            newMinimumThreshold > 0,
            "Minimum threshold must be greater than 0"
        );
        uint256 oldThreshold = pantosForwarder
            .getMinimumValidatorNodeSignatures();
        require(
            oldThreshold != newMinimumThreshold,
            "New threshold is the same as the old one"
        );
        address[] memory validatorNodes = pantosForwarder.getValidatorNodes();
        require(
            newMinimumThreshold <= validatorNodes.length,
            "New threshold is higher than the number of validator nodes"
        );

        vm.broadcast(accessController.pauser());
        pantosForwarder.pause();
        console.log("Pantos forwarder paused: %s", pantosForwarder.paused());

        vm.startBroadcast(accessController.superCriticalOps());
        pantosForwarder.setMinimumValidatorNodeSignatures(newMinimumThreshold);
        pantosForwarder.unpause();
        console.log(
            "Minimum validator node signatures set to %s, old value was %s",
            newMinimumThreshold,
            oldThreshold
        );
        console.log("Pantos forwarder paused: %s", pantosForwarder.paused());
        vm.stopBroadcast();

        writeAllSafeInfo(accessController);
    }
}
