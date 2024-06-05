// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.23;
pragma abicoder v2;

import {LibDiamond} from "@diamond/libraries/LibDiamond.sol";

import {PantosHubStorage} from "../PantosHubStorage.sol";

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
     * Pantos Hub owner is allowed.
     */
    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    /**
     * @notice Modifier which makes sure that only a transaction from the
     * Pantos Hub owner is allowed or the contract is not paused.
     */
    modifier ownerOrNotPaused() {
        if (s.paused) {
            LibDiamond.enforceIsContractOwner();
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
}
