// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;
pragma abicoder v2;

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {PantosToken} from "../../src/PantosToken.sol";

import {Constants} from "./Constants.s.sol";
import {PantosBaseScript} from "./PantosBaseScript.s.sol";

abstract contract PantosForwarderDeployer is PantosBaseScript {
    function deployPantosForwarder() public returns (PantosForwarder) {
        PantosForwarder pantosForwarder = new PantosForwarder();
        console2.log(
            "PantosForwarder deployed; paused=%s; address=%s",
            pantosForwarder.paused(),
            address(pantosForwarder)
        );
        return pantosForwarder;
    }

    function initializePantosForwarder(
        PantosForwarder pantosForwarder,
        IPantosHub pantosHubProxy,
        PantosToken pantosToken,
        address[] memory validatorNodeAddresses
    ) public {
        // Set the hub, PAN token, and validator node addresses
        pantosForwarder.setPantosHub(address(pantosHubProxy));
        console2.log(
            "PantosForwarder.setPantosHub(%s)",
            address(pantosHubProxy)
        );

        pantosForwarder.setPantosToken(address(pantosToken));
        console2.log(
            "PantosForwarder.setPantosToken(%s)",
            address(pantosToken)
        );

        for (uint i = 0; i < validatorNodeAddresses.length; i++) {
            pantosForwarder.addValidatorNode(validatorNodeAddresses[i]);
            console2.log(
                "PantosForwarder.addValidatorNode(%s)",
                validatorNodeAddresses[i]
            );
        }

        pantosForwarder.setMinimumValidatorNodeSignatures(
            Constants.MINIMUM_VALIDATOR_NODE_SIGNATURES
        );
        console2.log(
            "PantosForwarder.setMinimumValidatorNodeSignatures(%s)",
            vm.toString(Constants.MINIMUM_VALIDATOR_NODE_SIGNATURES)
        );

        // Unpause the forwarder contract after initialization
        pantosForwarder.unpause();

        console2.log(
            "PantosForwarder initialized; paused=%s",
            pantosForwarder.paused()
        );
    }
}
