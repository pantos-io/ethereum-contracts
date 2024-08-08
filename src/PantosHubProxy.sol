// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {LibDiamond} from "@diamond/libraries/LibDiamond.sol";
import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";

import {LibAccessControl} from "./libraries/LibAccessControl.sol";
import {AccessController} from "./access/AccessController.sol";

/**
 * @title Pantos Hub proxy
 *
 * @notice EIP-2535 Diamond Standard proxy implemenation based on Nick Mudge's
 * diamond-3 reference with minor modification.
 * EIP-2535 Diamond Standard: <https://eips.ethereum.org/EIPS/eip-2535>.
 * Reference Implementation: <https://github.com/mudgen/diamond-3-hardhat>.
 *
 * @dev Entrypoint for all Pantos-Hub-related functions served by multiple
 * facets behind it. All the facets can be upgraded independently.
 * Modification to reference implementation: `receive()` function is removed
 * to restrict sending Ether directly to this contract.
 *
 * @author Pantos GmbH
 * @author Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
 */
contract PantosHubProxy {
    /**
     * @notice Add intial diamond cut facet and set access controller.
     *
     * @param _diamondCutFacet Diamond facet address.
     * @param _accessController Access controller address.
     */
    constructor(address _diamondCutFacet, address _accessController) payable {
        LibAccessControl.setAccessController(_accessController);

        // Add the diamondCut external function from the diamondCutFacet
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IDiamondCut.diamondCut.selector;
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: _diamondCutFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
        LibDiamond.diamondCut(cut, address(0), "");
    }

    /**
     * @notice Find facet for function that is called and execute the
     * function if a facet is found and return any value.
     *
     * @dev Fallback function is used to implement routing to facets.
     */
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        // get diamond storage
        // slither-disable-next-line assembly
        assembly {
            ds.slot := position
        }
        // get facet from function selector
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "PantosHub: Function does not exist");
        // Execute external function from facet using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
