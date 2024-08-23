// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;
import {LibDiamond} from "@diamond/libraries/LibDiamond.sol";

import {PantosHubStorage} from "../PantosHubStorage.sol";
import {PantosRoles} from "../access/PantosRoles.sol";
import {LibAccessControl} from "../libraries/LibAccessControl.sol";

/**
 * @notice Base class for all Pantos-Hub-related facets which shares 
 * PantosHubStorage (App Storage pattern for Diamond Proxy implementation).
 * It also has common modifiers and internal functions used by the facets.

 * @dev Should not have any public methods or else inheriting facets will
 * duplicate methods accidentally. App storage PantosHubStorage declaration 
 * should be the first thing.
 */
abstract contract PantosBaseFacet {
    // Application of the App Storage pattern
    PantosHubStorage internal s;
    /**
     * @notice Modifier which makes sure that only a transaction from the
     * Pantos Hub deployer role is allowed or the contract is not paused.
     */
    modifier deployerOrNotPaused() {
        if (s.paused) {
            LibAccessControl.AccessControlStorage
                storage acs = LibAccessControl.accessControlStorage();
            require(
                acs.accessController.hasRole(PantosRoles.DEPLOYER, msg.sender),
                "PantosHub: caller doesn't have role"
            );
        }
        _;
    }

    /**
     * @notice Modifier which makes sure that only a transaction from
     * the primary validator node is allowed.
     */
    modifier onlyPrimaryValidatorNode() {
        require(
            msg.sender == s.primaryValidatorNodeAddress,
            "PantosHub: caller is not the primary validator node"
        );
        _;
    }

    /**
     * @notice Modifier which makes sure that a transaction is allowed
     * only if the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!s.paused, "PantosHub: paused");
        _;
    }

    /**
     * @notice Modifier which makes sure that a transaction is allowed only
     * if the contract is paused.
     */
    modifier whenPaused() {
        require(s.paused, "PantosHub: not paused");
        _;
    }

    modifier onlyRole(bytes32 _role) {
        LibAccessControl.AccessControlStorage storage acs = LibAccessControl
            .accessControlStorage();
        require(
            acs.accessController.hasRole(_role, msg.sender),
            "PantosHub: caller doesn't have role"
        );
        _;
    }
}
