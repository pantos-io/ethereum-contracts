// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;


/* solhint-disable no-console*/

import {PantosForwarder} from "../../src/PantosForwarder.sol";

import {PantosForwarderRedeployer} from "../helpers/PantosForwarderRedeployer.s.sol";

/**
 * @title RedeployForwarder
 *
 * @notice Redeploy the Pantos Forwarder
 * To ensure correct functionality of the newly deployed Pantos Forwarder
 * within the Pantos protocol, the following steps are incorporated into
 * this script:
 *
 * 1. Retrieve the validator node addresses from the previous Pantos
 * Forwarder and configure it in the new Pantos Forwarder.
 * 2. Retrieve the Pantos token address from the Pantos Hub and
 * configure it in the new Pantos Forwarder.
 * 3. Configure the new Pantos Forwarder at the Pantos Hub.
 * 4. Configure the new Pantos Forwarder at Pantos, Best and Wrapper tokens.
 *
 * @dev Usage
 * forge script ./script/redeploy/RedeployForwarder.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "run(address)" <pantosHubProxyAddress>
 */
contract RedeployForwarder is PantosForwarderRedeployer {
    function run(address pantosHubProxyAddress) public {
        vm.startBroadcast();

        initializePantosForwarderRedeployer(pantosHubProxyAddress);

        PantosForwarder pantosForwarder = deployAndInitializePantosForwarder();
        migrateForwarderAtHub(pantosForwarder);
        migrateForwarderAtTokens(pantosForwarder);

        vm.stopBroadcast();
    }
}
