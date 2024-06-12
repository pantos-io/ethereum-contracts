// SPDX-License-Identifier: MIT
// slither-disable-next-line solc-version
pragma solidity 0.8.26;
pragma abicoder v2;

/**
 * @title Pantos Hub initializer
 *
 * @notice This contract is used for one-off initialization of Pantos Hub.
 * It contains a single function `init`, which is intended to be called by
 * Diamond Cut Facet during the initial setup and configuration of Pantos Hub
 * with the specified parameters.
 *
 * @dev This is not designed for repeated initializations. It will revert if
 * attempted to call it more than once with subsequent diamond cut.
 * The `init` function should not be called directly. It is meant to be invoked
 * by the diamond cut facet using delegatecall to initialize the state of
 * Pantos Hub.
 */

import {LibDiamond} from "@diamond/libraries/LibDiamond.sol";
import {IDiamondLoupe} from "@diamond/interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";
import {IERC173} from "@diamond/interfaces/IERC173.sol";
import {IERC165} from "@diamond/interfaces/IERC165.sol";

import {PantosHubStorage} from "../PantosHubStorage.sol";

contract PantosHubInit {
    PantosHubStorage internal ps;

    struct Args {
        uint256 blockchainId;
        string blockchainName;
        uint256 minimumTokenStake;
        uint256 minimumServiceNodeStake;
        uint256 unbondingPeriodServiceNodeStake;
        uint256 feeFactor;
        uint256 feeFactorValidFrom;
        uint256 minimumValidatorFeeUpdatePeriod;
        uint256 nextTransferId;
    }

    /**
     * @dev Initializes the storage with provided arguments.
     *
     * @param args The struct containing initialization arguments.
     */
    function init(Args memory args) external {
        // safety check to ensure, init is only called once
        require(
            ps.initialized == 0,
            "PantosHubInit: contract is already initialized"
        );
        ps.initialized = 1;

        // adding ERC165 data
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        // initialising PantosHubStorage
        ps.paused = true;
        // Register the current blockchain
        ps.currentBlockchainId = args.blockchainId;
        require(
            bytes(args.blockchainName).length > 0,
            "PantosHubInit: blockchain name must not be empty"
        );

        // Store the blockchain record
        ps.blockchainRecords[args.blockchainId].active = true;
        ps.blockchainRecords[args.blockchainId].name = args.blockchainName;
        ps.numberBlockchains = args.blockchainId + 1;
        ps.numberActiveBlockchains++;
        ps.minimumValidatorFeeUpdatePeriod = args
            .minimumValidatorFeeUpdatePeriod;

        // update fee factor
        require(args.feeFactor >= 1, "PantosHubInit: newFactor must be >= 1");
        // slither-disable-next-line timestamp
        require(
            args.feeFactorValidFrom >=
                block.timestamp + args.minimumValidatorFeeUpdatePeriod,
            "PantosHubInit: validFrom must be larger than "
            "(block timestamp + minimum update period)"
        );

        ps.validatorFeeRecords[args.blockchainId].newFactor = args.feeFactor;
        ps.validatorFeeRecords[args.blockchainId].validFrom = args
            .feeFactorValidFrom;

        // Set the minimum stakes
        ps.minimumTokenStake = args.minimumTokenStake;
        ps.minimumServiceNodeStake = args.minimumServiceNodeStake;
        ps.unbondingPeriodServiceNodeStake = args
            .unbondingPeriodServiceNodeStake;
        // Set the next transfer ID (is greater than 0 if there have already
        // been prior Pantos transfers initiated on the current blockchain)
        ps.nextTransferId = args.nextTransferId;
    }
}
