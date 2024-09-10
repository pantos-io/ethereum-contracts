// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {AccessController} from "../../src/access/AccessController.sol";
import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {PantosHubInit} from "../../src/upgradeInitializers/PantosHubInit.sol";
import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {PantosTypes} from "../../src/interfaces/PantosTypes.sol";
import {PantosHubProxy} from "../../src/PantosHubProxy.sol";

import {PantosHubRedeployer} from "../helpers/PantosHubRedeployer.s.sol";
import {PantosFacets} from "../helpers/PantosHubDeployer.s.sol";

/**
 * @title RedeployHub
 *
 * @notice Redeploy the Pantos Hub.
 * To ensure correct functionality of the newly deployed Pantos Hub within the
 * Pantos protocol, the following steps are incorporated into this script:
 *
 * 1. Retrieve the primary validator node address from the previous
 * Pantos Hub and configure it in the new Pantos Hub.
 * 2. Retrieve the Pantos Forwarder address from the previous Pantos Hub and
 * configure it in the new Pantos Hub.
 * 3. Retrieve the Pantos token address from the previous Pantos Hub and
 * configure it in the new Pantos Hub.
 * 4. Configure the new Pantos Hub at the Pantos Forwarder.
 * 5. Migrate the tokens owned by the sender account from the old Pantos Hub
 * to the new one.
 *
 * @dev Usage
 * forge script ./script/redeploy/RedeployHub.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "run(address,uint256)" <oldPantosHubProxyAddress>
 */
contract RedeployHub is PantosHubRedeployer {
    function migrateHubAtForwarder(
        IPantosHub newPantosHubProxy,
        PantosForwarder pantosForwarder
    ) public onlyPantosHubRedeployerInitialized {
        pantosForwarder.setPantosHub(address(newPantosHubProxy));
        pantosForwarder.unpause();
        console.log(
            "PantosForwarder.setPantosHub(%s); paused=%s",
            address(newPantosHubProxy),
            pantosForwarder.paused()
        );
    }

    // this will write all deployed pantosHubProxy,pantosHubInit & pantosFacets to <blockchainName>-DEPLOY.json
    function deploy(address accessControllerAddress) public {
        vm.startBroadcast();

        AccessController accessController = AccessController(
            accessControllerAddress
        );
        PantosHubProxy pantosHubProxy;
        PantosHubInit pantosHubInit;
        PantosFacets memory pantosFacets;

        (pantosHubProxy, pantosHubInit, pantosFacets) = deployPantosHub(
            accessController
        );
        // exportContractAddresses(); FIXME
    }

    // this will read new contracts deployed from <blockchainName>-DEPLOY.json
    // this will also read current addresses from <blockchainName>.json -- update it at end of the script
    function roleActions() public {
        address oldPantosHubProxyAddress; // FIXME from <blockchainName>.json
        AccessController accessController; // FIXME from <blockchainName>.json

        initializePantosHubRedeployer(oldPantosHubProxyAddress);
        IPantosHub oldPantosHub = getOldPantosHubProxy();

        uint256 nextTransferId = oldPantosHub.getNextTransferId();
        // FIXME read json for new pantosHubProxy, pantosHubInit and pantosFacets from <blockchainName>-DEPLOY.json
        PantosHubProxy newPantosHubProxy; // FIXME
        PantosHubInit newPantosHubInit; // FIXME
        PantosFacets memory newPantosFacets; // FIXME

        vm.broadcast(accessController.pauser());
        pausePantosHub(oldPantosHub);

        address primaryValidatorNodeAddress = oldPantosHub
            .getPrimaryValidatorNode();

        vm.broadcast(accessController.deployer());
        diamondCutFacets(
            newPantosHubProxy,
            newPantosHubInit,
            newPantosFacets,
            nextTransferId
        );

        IPantosHub newPantosHub = IPantosHub(address(newPantosHubProxy));

        vm.broadcast(accessController.superCriticalOps());
        initializePantosHub(
            IPantosHub(newPantosHub),
            getPantosForwarder(),
            getPantosToken(),
            primaryValidatorNodeAddress
        );

        PantosForwarder pantosForwarder = getPantosForwarder();

        if (!pantosForwarder.paused()) {
            vm.broadcast(accessController.pauser());
            pantosForwarder.pause();
        }
        vm.startBroadcast(accessController.superCriticalOps());
        migrateHubAtForwarder(newPantosHub, pantosForwarder);
        migrateTokensFromOldHubToNewHub(
            IPantosHub(address(newPantosHubProxy))
        );
        vm.stopBroadcast();
    }
}
