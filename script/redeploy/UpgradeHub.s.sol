// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;
pragma abicoder v2;

import "../helpers/PantosHubDeployer.s.sol";

/**
 * @title UpgradeHub
 *
 * @notice Deploy and upgrade the logic contract of the Pantos Hub contract.
 *
 * @dev Usage
 * forge script ./script/redeploy/UpgradeHub.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "run(address,address)" <proxyAdminAddress> <transparentProxyAddress>
 */
contract UpgradeHub is PantosHubDeployer {
    function run(
        address proxyAdminAddress,
        address transparentProxyAddress
    ) public {
        vm.startBroadcast();

        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
        ITransparentUpgradeableProxy transparentProxy = ITransparentUpgradeableProxy(
                transparentProxyAddress
            );

        upgradePantosHub(proxyAdmin, transparentProxy);

        vm.stopBroadcast();
    }
}
