// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {PantosRegistryFacet} from "../../src/facets/PantosRegistryFacet.sol";
import {PantosTransferFacet} from "../../src/facets/PantosTransferFacet.sol";
import {AccessController} from "../../src/access/AccessController.sol";
import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {PantosToken} from "../../src/PantosToken.sol";

import {PantosHubDeployer} from "../helpers/PantosHubDeployer.s.sol";
import {PantosForwarderRedeployer} from "../helpers/PantosForwarderRedeployer.s.sol";

/**
 * @title UpgradeHubAndRedeployForwarder
 *
 * @notice Deploy and upgrade facets of the Pantos Hub and redeploys the
 * Pantos Forwarder. To ensure correct functionality of the newly deployed
 * Pantos Forwarder within the Pantos protocol, the following steps are
 * incorporated into this script:
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
 *     --sig "run(address)" <pantosHubProxyAddress>
 */
contract UpgradeHubAndRedeployForwarder is
    PantosHubDeployer,
    PantosForwarderRedeployer
{
    PantosRegistryFacet registryFacet;
    PantosTransferFacet transferFacet;

    // this will write new facets deployed to <blockchainName>-DEPLOY.json
    function deploy(address accessControllerAddress) public {
        AccessController accessController = AccessController(
            accessControllerAddress
        );

        vm.startBroadcast();

        registryFacet = deployRegistryFacet();
        transferFacet = deployTransferFacet();
        PantosForwarder pantosForwarder = deployPantosForwarder(
            accessController
        );

        vm.stopBroadcast();
        // exportContractAddresses();
    }

    function roleActions() public {
        address pantosHubProxyAddress; // FIXME: need this from <blockchainName>.json
        AccessController accessController; // FIXME from <blockchainName>.json

        // importContractAddresses(); // FIXME read new facet, forwarder deployed to <blockchainName>-DEPLOY.json
        IPantosHub pantosHub = IPantosHub(pantosHubProxyAddress);
        PantosForwarder newPantosForwarder; // FIXME read from <blockchainName>-DEPLOY.json

        // vm.startBroadcast();
        initializePantosForwarderRedeployer(pantosHubProxyAddress);

        // Ensuring PantosHub is paused at the time of diamond cut
        vm.broadcast(accessController.pauser());
        pausePantosHub(pantosHub);

        vm.broadcast(accessController.deployer());
        diamondCutUpgradeFacets(
            pantosHubProxyAddress,
            registryFacet,
            transferFacet
        );

        // this will do nothing if there is nothing new added to the storage slots
        // FIXME: can we use the json valuse to pass in to this method ?
        vm.broadcast(accessController.superCriticalOps());
        initializePantosHub(
            pantosHub,
            PantosForwarder(pantosHub.getPantosForwarder()),
            PantosToken(pantosHub.getPantosToken()),
            pantosHub.getPrimaryValidatorNode()
        );

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
