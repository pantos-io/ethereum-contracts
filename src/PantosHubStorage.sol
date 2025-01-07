// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {PantosTypes} from "./interfaces/PantosTypes.sol";

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
    PantosTypes.UpdatableUint256 minimumServiceNodeDeposit;
    address[] tokens;
    mapping(address => uint256) tokenIndices;
    mapping(address => PantosTypes.TokenRecord) tokenRecords;
    // Token address => blockchain ID => external token record
    mapping(address => mapping(uint256 => PantosTypes.ExternalTokenRecord)) externalTokenRecords;
    address[] serviceNodes;
    mapping(address => uint256) serviceNodeIndices;
    mapping(address => PantosTypes.ServiceNodeRecord) serviceNodeRecords;
    uint256 nextTransferId;
    // Source blockchain ID => source transfer ID => already used?
    mapping(uint256 => mapping(uint256 => bool)) usedSourceTransferIds;
    mapping(uint256 => PantosTypes.UpdatableUint256) validatorFeeFactors;
    PantosTypes.UpdatableUint256 parameterUpdateDelay;
    PantosTypes.UpdatableUint256 unbondingPeriodServiceNodeDeposit;
    mapping(bytes32 => bool) isServiceNodeUrlUsed;
    bytes32 protocolVersion;
}
