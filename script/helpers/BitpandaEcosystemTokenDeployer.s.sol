// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {BitpandaEcosystemToken} from "../../src/BitpandaEcosystemToken.sol";

import {PantosBaseScript} from "./PantosBaseScript.s.sol";

abstract contract BitpandaEcosystemTokenDeployer is PantosBaseScript {
    function deployBitpandaEcosystemToken(
        uint256 initialSupply
    ) public returns (BitpandaEcosystemToken) {
        BitpandaEcosystemToken bitpandaEcosystemToken = new BitpandaEcosystemToken(
                initialSupply
            );
        console2.log(
            "%s deployed; paused=%s; address=%s",
            bitpandaEcosystemToken.name(),
            bitpandaEcosystemToken.paused(),
            address(bitpandaEcosystemToken)
        );
        return bitpandaEcosystemToken;
    }

    function initializeBitpandaEcosystemToken(
        BitpandaEcosystemToken bitpandaEcosystemToken,
        IPantosHub pantosHubProxy,
        PantosForwarder pantosForwarder
    ) public {
        bitpandaEcosystemToken.setPantosForwarder(address(pantosForwarder));

        // Register token at Pantos hub
        pantosHubProxy.registerToken(address(bitpandaEcosystemToken));

        bitpandaEcosystemToken.unpause();

        console2.log(
            "%s initialized; paused=%s",
            bitpandaEcosystemToken.name(),
            bitpandaEcosystemToken.paused()
        );
    }
}
