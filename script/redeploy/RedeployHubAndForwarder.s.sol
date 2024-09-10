// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {AccessController} from "../../src/access/AccessController.sol";
import {PantosHubProxy} from "../../src/PantosHubProxy.sol";
import {PantosHubInit} from "../../src/upgradeInitializers/PantosHubInit.sol";

import {PantosForwarderRedeployer} from "../helpers/PantosForwarderRedeployer.s.sol";
import {PantosHubRedeployer} from "../helpers/PantosHubRedeployer.s.sol";
import {PantosFacets} from "../helpers/PantosHubDeployer.s.sol";

/**
 * @title RedeployHubAndForwarder
 *
 * @notice Redeploy the Pantos Hub and the Pantos Forwarder.
 * To ensure correct functionality of the newly deployed Pantos Hub
 * and Pantos Forwarder within the Pantos protocol, the following
 * steps are incorporated into this script:
 *
 * 1. Retrieve the validator node addresses from the previous Pantos Hub
 * and Forwarder and configure it in the new Pantos Hub and Forwarder.
 * 2. Retrieve the Pantos Forwarder address from the previous Pantos Hub and
 * configure it in the new Pantos Hub.
 * 3. Retrieve the Pantos token address from the previous Pantos Hub and
 * configure it in the new Pantos Hub and the Pantos Forwarder.
 * 4. Configure the new Pantos Hub at the Pantos Forwarder.
 * 5. Configure the new Pantos Forwarder at the Pantos Hub.
 * 5. Configure the new Pantos Forwarder at Pantos, Best and Wrapper tokens.
 * 6. Migrate the tokens owned by the sender account from the old Pantos Hub
 * to the new one.
 *
 * @dev Usage
 * forge script ./script/redeploy/RedeployHubAndForwarder.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "run(address)" <oldPantosHubProxyAddress>
 */
contract RedeployHubAndForwarder is
    PantosHubRedeployer,
    PantosForwarderRedeployer
{
    // this will write all deployed pantosHubProxy,pantosHubInit, pantosFacets forwarder
    // to <blockchainName>-DEPLOY.json
    function deploy(address accessControllerAddress) public {
        AccessController accessController = AccessController(
            accessControllerAddress
        );
        PantosHubProxy pantosHubProxy;
        PantosHubInit pantosHubInit;
        PantosFacets memory pantosFacets;

        (pantosHubProxy, pantosHubInit, pantosFacets) = deployPantosHub(
            accessController
        );

        PantosForwarder newPantosForwarder = deployPantosForwarder(
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
        PantosForwarder newPantosForwarder; // FIXME

        vm.broadcast(accessController.pauser());
        pausePantosHub(oldPantosHub);

        address primaryValidatorNodeAddress = oldPantosHub
            .getPrimaryValidatorNode();

        PantosForwarder oldForwarder = PantosForwarder(
            oldPantosHub.getPantosForwarder()
        );
        address[] memory validatorNodeAddresses = oldForwarder
            .getValidatorNodes();

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
            newPantosHub,
            newPantosForwarder,
            getPantosToken(),
            primaryValidatorNodeAddress
        );

        vm.broadcast(accessController.superCriticalOps());
        initializePantosForwarder(
            newPantosForwarder,
            newPantosHub,
            getPantosToken(),
            validatorNodeAddresses
        );

        // Pause old forwarder
        vm.broadcast(accessController.pauser());
        pauseForwarder(oldForwarder);

        // Migrate
        vm.broadcast(accessController.superCriticalOps());
        migrateTokensFromOldHubToNewHub(newPantosHub);

        // vm.broadcast is done in the function
        migrateForwarderAtTokens(
            newPantosForwarder,
            accessController.pauser(),
            accessController.superCriticalOps()
        );
    }
}
