// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;
pragma abicoder v2;

import "../helpers/PantosHubDeployer.s.sol";
import "../helpers/PantosForwarderRedeployer.s.sol";

/**
 * @title UpgradeHubAndRedeployForwarder
 *
 * @notice Deploy and upgrade the logic contract of the Pantos Hub contract and
 * redeploys the Pantos Forwarder. To ensure correct functionality of the newly
 * deployed Pantos Forwarder within the Pantos protocol, the following steps
 * are incorporated into this script:
 *
 * 1. Retrieve the validator address from the Pantos Hub and
 * configure it in the new Pantos Forwarder.
 * 2. Retrieve the Pantos token address from the Pantos Hub and
 * configure it in the new Pantos Forwarder.
 * 3. Configure the new Pantos Forwarder at the Pantos Hub.
 * 4. Configure the new Pantos Forwarder at Pantos, Best and Wrapper tokens.
 * @dev Usage
 * forge script ./script/redeploy/UpgradeHubAndRedeployForwarder.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "run(address,address)" <proxyAdminAddress> <pantosHubProxyAddress>
 */
contract UpgradeHubAndRedeployForwarder is
    PantosHubDeployer,
    PantosForwarderRedeployer
{
    function run(
        address proxyAdminAddress,
        address pantosHubProxyAddress
    ) public {
        vm.startBroadcast();

        initializePantosForwarderRedeployer(pantosHubProxyAddress);

        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
        ITransparentUpgradeableProxy transparentProxy = ITransparentUpgradeableProxy(
                pantosHubProxyAddress
            );
        upgradePantosHub(proxyAdmin, transparentProxy);

        PantosForwarder pantosForwarder = deployAndInitializePantosForwarder();
        migrateForwarderAtHub(pantosForwarder);
        migrateForwarderAtTokens(pantosForwarder);

        vm.stopBroadcast();
    }
}
