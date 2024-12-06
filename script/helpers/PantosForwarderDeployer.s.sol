// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {PantosToken} from "../../src/PantosToken.sol";
import {AccessController} from "../../src/access/AccessController.sol";

import {Constants} from "./Constants.s.sol";
import {PantosBaseScript} from "./PantosBaseScript.s.sol";

abstract contract PantosForwarderDeployer is PantosBaseScript {
    function deployPantosForwarder(
        AccessController accessController
    ) public returns (PantosForwarder) {
        PantosForwarder pantosForwarder = new PantosForwarder(
            Constants.MAJOR_PROTOCOL_VERSION,
            address(accessController)
        );
        console.log(
            "PantosForwarder deployed; paused=%s; address=%s; "
            "accessController=%s",
            pantosForwarder.paused(),
            address(pantosForwarder),
            address(accessController)
        );
        return pantosForwarder;
    }

    function initializePantosForwarder(
        PantosForwarder pantosForwarder,
        IPantosHub pantosHubProxy,
        PantosToken pantosToken,
        uint256 minimumValidatorNodeSignatures,
        address[] memory validatorNodeAddresses
    ) public {
        // Set the hub, PAN token, and validator node addresses
        pantosForwarder.setPantosHub(address(pantosHubProxy));
        console.log(
            "PantosForwarder.setPantosHub(%s)",
            address(pantosHubProxy)
        );

        pantosForwarder.setPantosToken(address(pantosToken));
        console.log(
            "PantosForwarder.setPantosToken(%s)",
            address(pantosToken)
        );

        for (uint i = 0; i < validatorNodeAddresses.length; i++) {
            pantosForwarder.addValidatorNode(validatorNodeAddresses[i]);
            console.log(
                "PantosForwarder.addValidatorNode(%s)",
                validatorNodeAddresses[i]
            );
        }

        pantosForwarder.setMinimumValidatorNodeSignatures(
            minimumValidatorNodeSignatures
        );
        console.log(
            "PantosForwarder.setMinimumValidatorNodeSignatures(%s)",
            vm.toString(minimumValidatorNodeSignatures)
        );

        // Unpause the forwarder contract after initialization
        pantosForwarder.unpause();

        console.log(
            "PantosForwarder initialized; paused=%s",
            pantosForwarder.paused()
        );
    }

    function pauseForwarder(PantosForwarder pantosForwarder) public {
        if (!pantosForwarder.paused()) {
            pantosForwarder.pause();
            console.log(
                "PantosForwarder(%s): paused=%s",
                address(pantosForwarder),
                pantosForwarder.paused()
            );
        }
    }
}
