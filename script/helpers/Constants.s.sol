// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;
pragma abicoder v2;

library Constants {
    uint256 public constant SERVICE_NODE_STAKE_UNBONDING_PERIOD = 604800;

    uint256 public constant MINIMUM_TOKEN_STAKE = 10 ** 3 * 10 ** 8;
    uint256 public constant MINIMUM_SERVICE_NODE_STAKE = 10 ** 5 * 10 ** 8;

    uint256 public constant FEE_FACTOR_VALID_FROM_OFFSET = 600; // seconds added to current timestamp

    // PantosToken
    uint256 public constant INITIAL_SUPPLY_PAN = (10 ** 9) * (10 ** 8);

    // bitpandaEcosystemToken
    uint256 public constant INITIAL_SUPPLY_BEST = (10 ** 9) * (10 ** 8);

    uint256 public constant MINIMUM_VALIDATOR_NODE_SIGNATURES = 1;

    uint256 public constant MINIMUM_VALIDATOR_FEE_UPDATE_PERIOD = 0;
}
