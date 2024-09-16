// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";
import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";

import {AccessController} from "../../src/access/AccessController.sol";
import {DiamondCutFacet} from "../../src/facets/DiamondCutFacet.sol";
import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {PantosHubInit} from "../../src/upgradeInitializers/PantosHubInit.sol";
import {PantosHubProxy} from "../../src/PantosHubProxy.sol";
import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {PantosToken} from "../../src/PantosToken.sol";
import {PantosTypes} from "../../src/interfaces/PantosTypes.sol";

import {PantosRegistryFacet} from "../../src/facets/PantosRegistryFacet.sol";
import {PantosTransferFacet} from "../../src/facets/PantosTransferFacet.sol";

import {PantosBaseAddresses} from "../helpers/PantosBaseAddresses.s.sol";
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
contract RedeployHub is PantosBaseAddresses, PantosHubRedeployer {
    AccessController accessController;
    PantosHubProxy newPantosHubProxy;
    PantosHubInit newPantosHubInit;
    PantosFacets newPantosFacets;
    IPantosHub oldPantosHub;

    function migrateHubAtForwarder(
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

    function deploy(address accessControllerAddress) public {
        accessController = AccessController(accessControllerAddress);

        vm.startBroadcast();
        (
            newPantosHubProxy,
            newPantosHubInit,
            newPantosFacets
        ) = deployPantosHub(accessController);
        exportRedeployedContractAddresses();
    }

    function roleActions() public {
        importContractAddresses();
        initializePantosHubRedeployer(oldPantosHub);

        uint256 nextTransferId = oldPantosHub.getNextTransferId();

        vm.broadcast(accessController.pauser());
        pausePantosHub(oldPantosHub);

        vm.broadcast(accessController.deployer());
        diamondCutFacets(
            newPantosHubProxy,
            newPantosHubInit,
            newPantosFacets,
            nextTransferId
        );

        IPantosHub newPantosHub = IPantosHub(address(newPantosHubProxy));
        PantosForwarder pantosForwarder = PantosForwarder(
            oldPantosHub.getPantosForwarder()
        );

        vm.broadcast(accessController.superCriticalOps());
        initializePantosHub(
            newPantosHub,
            pantosForwarder,
            PantosToken(oldPantosHub.getPantosToken()),
            oldPantosHub.getPrimaryValidatorNode()
        );

        if (!pantosForwarder.paused()) {
            vm.broadcast(accessController.pauser());
            pantosForwarder.pause();
        }

        vm.startBroadcast(accessController.superCriticalOps());
        migrateHubAtForwarder(pantosForwarder);
        migrateTokensFromOldHubToNewHub(newPantosHub);
        vm.stopBroadcast();

        overrideWithRedeployedAddresses();
    }

    function exportRedeployedContractAddresses() internal {
        ContractAddress[] memory contractAddresses = new ContractAddress[](6);
        contractAddresses[0] = ContractAddress(
            Contract.HUB_PROXY,
            address(newPantosHubProxy)
        );
        contractAddresses[1] = ContractAddress(
            Contract.HUB_INIT,
            address(newPantosHubInit)
        );
        contractAddresses[2] = ContractAddress(
            Contract.DIAMOND_CUT_FACET,
            address(newPantosFacets.dCut)
        );
        contractAddresses[3] = ContractAddress(
            Contract.DIAMOND_LOUPE_FACET,
            address(newPantosFacets.dLoupe)
        );
        contractAddresses[4] = ContractAddress(
            Contract.REGISTRY_FACET,
            address(newPantosFacets.registry)
        );
        contractAddresses[5] = ContractAddress(
            Contract.TRANSFER_FACET,
            address(newPantosFacets.transfer)
        );
        exportContractAddresses(contractAddresses, true);
    }

    function importContractAddresses() public {
        readContractAddresses(determineBlockchain());
        readRedeployedContractAddresses();

        // New contracts
        newPantosHubProxy = PantosHubProxy(
            payable(getContractAddress(Contract.HUB_PROXY, true))
        );

        newPantosHubInit = PantosHubInit(
            getContractAddress(Contract.HUB_INIT, true)
        );
        newPantosFacets = PantosFacets(
            DiamondCutFacet(
                getContractAddress(Contract.DIAMOND_CUT_FACET, true)
            ),
            DiamondLoupeFacet(
                getContractAddress(Contract.DIAMOND_LOUPE_FACET, true)
            ),
            PantosRegistryFacet(
                getContractAddress(Contract.REGISTRY_FACET, true)
            ),
            PantosTransferFacet(
                getContractAddress(Contract.TRANSFER_FACET, true)
            )
        );
        // Old contracts
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );

        oldPantosHub = IPantosHub(
            payable(getContractAddress(Contract.HUB_PROXY, false))
        );
    }
}
