// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {PantosHubProxy} from "../../src/PantosHubProxy.sol";
import {AccessController} from "../../src/access/AccessController.sol";
import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {PantosToken} from "../../src/PantosToken.sol";

import {PantosHubDeployer} from "../helpers/PantosHubDeployer.s.sol";
import {PantosBaseAddresses} from "../helpers/PantosBaseAddresses.s.sol";
import {PantosRegistryFacet} from "../../src/facets/PantosRegistryFacet.sol";
import {PantosTransferFacet} from "../../src/facets/PantosTransferFacet.sol";
import {SafeAddresses} from "../helpers/SafeAddresses.s.sol";

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
contract UpgradeHub is PantosBaseAddresses, SafeAddresses, PantosHubDeployer {
    PantosHubProxy pantosHubProxy;
    PantosForwarder pantosForwarder;
    PantosToken pantosToken;
    AccessController accessController;

    PantosRegistryFacet newRegistryFacet;
    PantosTransferFacet newTransferFacet;

    function deploy() public {
        vm.startBroadcast();
        newRegistryFacet = deployRegistryFacet();
        newTransferFacet = deployTransferFacet();
        vm.stopBroadcast();
        exportUpgradedContractAddresses();
    }

    // this will also read current addresses from <blockchainName>.json -- update it at end of the script
    function roleActions() public {
        importContractAddresses();
        IPantosHub pantosHub = IPantosHub(address(pantosHubProxy));
        console.log("PantosHub", address(pantosHub));

        // Ensuring PantosHub is paused at the time of diamond cut
        vm.startBroadcast(accessController.pauser());
        pausePantosHub(pantosHub);
        vm.stopBroadcast();

        vm.startBroadcast(accessController.deployer());
        diamondCutUpgradeFacets(
            address(pantosHubProxy),
            newRegistryFacet,
            newTransferFacet
        );
        vm.stopBroadcast();

        // this will do nothing if there is nothing new added to the storage slots
        vm.startBroadcast(accessController.superCriticalOps());
        initializePantosHub(
            pantosHub,
            pantosForwarder,
            pantosToken,
            pantosHub.getPrimaryValidatorNode()
        );
        vm.stopBroadcast();
        overrideWithRedeployedAddresses();
        writeAllSafeInfo(accessController);
    }

    function exportUpgradedContractAddresses() public {
        ContractAddress[] memory contractAddresses = new ContractAddress[](2);
        contractAddresses[0] = ContractAddress(
            Contract.REGISTRY_FACET,
            address(newRegistryFacet)
        );
        contractAddresses[1] = ContractAddress(
            Contract.TRANSFER_FACET,
            address(newTransferFacet)
        );
        exportContractAddresses(contractAddresses, true);
    }

    function importContractAddresses() public {
        readContractAddresses(determineBlockchain());
        readRedeployedContractAddresses();
        newRegistryFacet = PantosRegistryFacet(
            getContractAddress(Contract.REGISTRY_FACET, true)
        );
        newTransferFacet = PantosTransferFacet(
            getContractAddress(Contract.TRANSFER_FACET, true)
        );
        pantosHubProxy = PantosHubProxy(
            payable(getContractAddress(Contract.HUB_PROXY, false))
        );
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        pantosForwarder = PantosForwarder(
            getContractAddress(Contract.FORWARDER, false)
        );
        pantosToken = PantosToken(getContractAddress(Contract.PAN, false));
    }
}
