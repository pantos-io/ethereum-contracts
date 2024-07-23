// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;


/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

import {IPantosHub} from "../src/interfaces/IPantosHub.sol";

import {Constants} from "./helpers/Constants.s.sol";
import {PantosBaseScript} from "./helpers/PantosHubDeployer.s.sol";

/**
 * @title UpdateFeeFactors
 *
 * @notice Update the fee factors at the Pantos Hub.
 *
 * @dev Usage
 * forge script ./script/UpdateFeeFactors.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "run(address)" <pantosHubProxy>
 */
contract UpdateFeeFactors is PantosBaseScript {
    function run(address pantosHubProxyAddress) public {
        IPantosHub pantosHubProxy = IPantosHub(pantosHubProxyAddress);
        uint256 feeFactorValidFrom = vm.unixTime() /
            1000 +
            Constants.FEE_FACTOR_VALID_FROM_OFFSET;

        vm.startBroadcast();

        for (uint256 i; i < getBlockchainsLength(); i++) {
            Blockchain memory blockchain = getBlockchainById(BlockchainId(i));
            if (!blockchain.skip) {
                pantosHubProxy.updateFeeFactor(
                    uint256(blockchain.blockchainId),
                    blockchain.feeFactor,
                    feeFactorValidFrom
                );
                console2.log("Fee factor of %s updated", blockchain.name);
            }
        }

        vm.stopBroadcast();
    }
}
