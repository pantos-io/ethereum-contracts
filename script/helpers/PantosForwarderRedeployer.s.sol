// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {PantosWrapper} from "../../src/PantosWrapper.sol";
import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {PantosToken} from "../../src/PantosToken.sol";
import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {AccessController} from "../../src/access/AccessController.sol";

import {PantosForwarderDeployer} from "../helpers/PantosForwarderDeployer.s.sol";

interface IOldPantosForwarder {
    function getPantosValidator() external returns (address);
}

abstract contract PantosForwarderRedeployer is PantosForwarderDeployer {
    function tryGetMinimumValidatorNodeSignatures(
        PantosForwarder oldForwarder
    ) public view returns (uint256) {
        uint256 minimumValidatorNodeSignatures;
        try oldForwarder.getMinimumValidatorNodeSignatures() returns (
            uint256 result
        ) {
            minimumValidatorNodeSignatures = result;
        } catch {
            console.log(
                "Method getMinimumValidatorNodeSignatures() not available"
            );
            minimumValidatorNodeSignatures = 1;
        }
        return minimumValidatorNodeSignatures;
    }

    function tryGetValidatorNodes(
        PantosForwarder oldForwarder
    ) public returns (address[] memory) {
        address[] memory validatorNodeAddresses;
        // Trying to call newly added function.
        // If it is not available, catch block will try older version
        try oldForwarder.getValidatorNodes() returns (
            address[] memory result
        ) {
            validatorNodeAddresses = result;
        } catch {
            // delete catch block if all envs updated with new contract
            console.log(
                "Failed to find new method getValidatorNodes(); "
                "will try old method getPantosValidator()"
            );
            validatorNodeAddresses = new address[](1);
            validatorNodeAddresses[0] = IOldPantosForwarder(
                address(oldForwarder)
            ).getPantosValidator();
        }
        return validatorNodeAddresses;
    }

    function migrateForwarderAtHub(
        PantosForwarder pantosForwarder,
        IPantosHub pantosHub
    ) public {
        require(
            pantosHub.paused(),
            "PantosHub should be paused before migrateForwarderAtHub"
        );
        pantosHub.setPantosForwarder(address(pantosForwarder));
        pantosHub.unpause();
        console.log(
            "PantosHub setPantosForwarder(%s); paused=%s",
            address(pantosForwarder),
            pantosHub.paused()
        );
    }

    function migrateNewForwarderAtToken(
        PantosForwarder pantosForwarder,
        PantosWrapper token
    ) public {
        require(
            token.paused(),
            "Token should be paused before migrateNewForwarderAtToken"
        );
        token.setPantosForwarder(address(pantosForwarder));
        token.unpause();
        console.log(
            "%s setPantosForwarder(%s); paused=%s",
            token.name(),
            address(pantosForwarder),
            token.paused()
        );
    }
}
