// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/

import {AccessController} from "../../src/access/AccessController.sol";
import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
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
    // this will write adeployed forwarder to <blockchainName>-DEPLOY.json
    function deploy(address accessControllerAddress) public {
        AccessController accessController = AccessController(
            accessControllerAddress
        );
        PantosForwarder newPantosForwarder = deployPantosForwarder(
            accessController
        );
        // exportContractAddresses(); FIXME
    }

    // this will read new contracts deployed from <blockchainName>-DEPLOY.json
    // this will also read current addresses from <blockchainName>.json -- update it at end of the script
    function roleActions() public {
        AccessController accessController; // FIXME from <blockchainName>.json
        address pantosHubProxyAddress; // FIXME from <blockchainName>.json
        PantosForwarder newPantosForwarder; // FIXME from <blockchainName>-DEPLOY.json

        IPantosHub pantosHub = IPantosHub(pantosHubProxyAddress);
        PantosForwarder oldForwarder = PantosForwarder(
            pantosHub.getPantosForwarder()
        );

        initializePantosForwarderRedeployer(pantosHubProxyAddress);

        vm.broadcast(accessController.superCriticalOps());
        initializePantosForwarder(newPantosForwarder);

        // Pause pantos Hub and old forwarder
        vm.startBroadcast(accessController.pauser());
        pauseForwarder(oldForwarder);
        pantosHub.pause();
        vm.stopBroadcast();

        vm.broadcast(accessController.superCriticalOps());
        migrateForwarderAtHub(newPantosForwarder);

        // vm.broadcast is done in the function
        migrateForwarderAtTokens(
            newPantosForwarder,
            accessController.pauser(),
            accessController.superCriticalOps()
        );
    }
}
