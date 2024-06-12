// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;
pragma abicoder v2;

import "./interfaces/PantosTypes.sol";

/**
 * @notice Pantos Hub storage state variables.
 * Used as App Storage struct for Pantos Hub Diamond Proxy implementation.
 */
struct PantosHubStorage {
    uint64 initialized;
    bool paused;
    address pantosForwarder;
    address pantosToken;
    address primaryValidatorNodeAddress;
    uint256 numberBlockchains;
    uint256 numberActiveBlockchains;
    uint256 currentBlockchainId;
    mapping(uint256 => PantosTypes.BlockchainRecord) blockchainRecords;
    uint256 minimumTokenStake;
    uint256 minimumServiceNodeStake;
    address[] tokens;
    mapping(address => PantosTypes.TokenRecord) tokenRecords;
    // Token address => blockchain ID => external token record
    mapping(address => mapping(uint256 => PantosTypes.ExternalTokenRecord)) externalTokenRecords;
    address[] serviceNodes;
    mapping(address => PantosTypes.ServiceNodeRecord) serviceNodeRecords;
    uint256 nextTransferId;
    // Source blockchain ID => source transfer ID => already used?
    mapping(uint256 => mapping(uint256 => bool)) usedSourceTransferIds;
    mapping(uint256 => PantosTypes.ValidatorFeeRecord) validatorFeeRecords;
    uint256 minimumValidatorFeeUpdatePeriod;
    uint256 unbondingPeriodServiceNodeStake;
    mapping(bytes32 => bool) isServiceNodeUrlUsed;
}
