// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";
import {LibDiamond} from "@diamond/libraries/LibDiamond.sol";

import {PantosRoles} from "../access/PantosRoles.sol";
import {PantosBaseFacet} from "./PantosBaseFacet.sol";

/**
 * @title DiamondCutFacet
 *
 * @notice Add/replace/remove any number of functions and optionally execute
 * a function with delegatecall.
 */
contract DiamondCutFacet is IDiamondCut, PantosBaseFacet {
    /**
     * @param _diamondCut Contains the facet addresses and function selectors
     * @param _init The address of the contract or facet to execute _calldata
     * @param _calldata A function call, including function selector and arguments
     */
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override onlyRole(PantosRoles.DEPLOYER) {
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
    }
}
