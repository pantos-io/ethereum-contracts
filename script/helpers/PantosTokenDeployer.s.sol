// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;


/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {PantosToken} from "../../src/PantosToken.sol";

import {Constants} from "./Constants.s.sol";
import {PantosBaseScript} from "./PantosBaseScript.s.sol";

abstract contract PantosTokenDeployer is PantosBaseScript {
    function deployPantosToken(
        uint256 initialSupply
    ) public returns (PantosToken) {
        PantosToken pantosToken = new PantosToken(initialSupply);
        console2.log(
            "%s deployed; paused=%s; address=%s",
            pantosToken.name(),
            pantosToken.paused(),
            address(pantosToken)
        );
        return pantosToken;
    }

    function initializePantosToken(
        PantosToken pantosToken,
        PantosForwarder pantosForwarder
    ) public {
        pantosToken.setPantosForwarder(address(pantosForwarder));
        pantosToken.unpause();
        console2.log(
            "%s initialized;  paused=%s",
            pantosToken.name(),
            pantosToken.paused()
        );
    }
}
