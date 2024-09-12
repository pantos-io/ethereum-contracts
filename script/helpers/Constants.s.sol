// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

library Constants {
    uint8 public constant MAJOR_PROTOCOL_VERSION = 0;

    uint256 public constant SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD = 604800;

    uint256 public constant MINIMUM_SERVICE_NODE_DEPOSIT = 10 ** 5 * 10 ** 8;

    // PantosToken
    uint256 public constant INITIAL_SUPPLY_PAN = (10 ** 9) * (10 ** 8);

    // BitpandaEcosystemToken
    uint256 public constant INITIAL_SUPPLY_BEST = (10 ** 9) * (10 ** 8);

    uint256 public constant MINIMUM_VALIDATOR_NODE_SIGNATURES = 1;

    uint256 public constant PARAMETER_UPDATE_DELAY = 3 days;
}
