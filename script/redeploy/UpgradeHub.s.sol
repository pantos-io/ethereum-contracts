// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
pragma abicoder v2;

import {PantosHubDeployer} from "../helpers/PantosHubDeployer.s.sol";

/**
 * @title UpgradeHub
 *
 * @notice Deploy and upgrade facets of the Pantos Hub.
 *
 * @dev Usage
 * forge script ./script/redeploy/UpgradeHub.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "run(address)" <pantosHubProxyAddress>
 */
contract UpgradeHub is PantosHubDeployer {
    function run(address pantosHubProxyAddress) public {
        vm.startBroadcast();

        upgradePantosHub(pantosHubProxyAddress);

        vm.stopBroadcast();
    }
}
