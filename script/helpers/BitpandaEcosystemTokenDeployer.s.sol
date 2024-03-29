// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;
pragma abicoder v2;

/* solhint-disable no-console*/

import "../../src/contracts/PantosHub.sol";
import "../../src/contracts/PantosForwarder.sol";
import "../../src/contracts/BitpandaEcosystemToken.sol";

import "./Constants.s.sol";
import "./PantosBaseScript.s.sol";

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
        PantosHub pantosHubProxy,
        PantosForwarder pantosForwarder
    ) public {
        bitpandaEcosystemToken.setPantosForwarder(address(pantosForwarder));

        // Register token at Pantos hub
        pantosHubProxy.registerToken(
            address(bitpandaEcosystemToken),
            Constants.MINIMUM_TOKEN_STAKE
        );

        bitpandaEcosystemToken.unpause();

        console2.log(
            "%s initialized; paused=%s",
            bitpandaEcosystemToken.name(),
            bitpandaEcosystemToken.paused()
        );
    }
}
