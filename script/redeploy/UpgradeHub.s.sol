// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";

import {PantosHubDeployer} from "../helpers/PantosHubDeployerNew.s.sol";
import {PantosRegistryFacet} from "../../src/facets/PantosRegistryFacet.sol";
import {PantosTransferFacet} from "../../src/facets/PantosTransferFacet.sol";

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
    PantosRegistryFacet registryFacet;
    PantosTransferFacet transferFacet;

    function exportContractAddresses() public {
        string memory blockchainName = determineBlockchain().name;
        string memory addresses;
        // for (uint256 i; i < pantosWrappers.length; i++) {
        //     vm.serializeAddress(
        //         "addresses",
        //         pantosWrappers[i].symbol(),
        //         address(pantosWrappers[i])
        //     );
        // }

        // vm.serializeAddress("addresses", "hub_proxy", address(pantosHubProxy));
        // vm.serializeAddress("addresses", "hub_init", address(pantosHubInit));
        // vm.serializeAddress(
        //     "addresses",
        //     "diamond_cut_facet",
        //     address(pantosFacets.dCut)
        // );
        // vm.serializeAddress(
        //     "addresses",
        //     "diamond_loupe_facet",
        //     address(pantosFacets.dLoupe)
        // );
        vm.serializeAddress(
            "addresses",
            "registry_facet",
            address(registryFacet)
        );
        addresses = vm.serializeAddress(
            "addresses",
            "transfer_facet",
            address(transferFacet)
        );

        // vm.serializeAddress(
        //     "addresses",
        //     "forwarder",
        //     address(pantosForwarder)
        // );
        // vm.serializeAddress("addresses", "pan", address(pantosToken));
        // vm.serializeAddress(
        //     "addresses",
        //     "access_controller",
        //     address(accessController)
        // );
        // addresses = vm.serializeAddress(
        //     "addresses",
        //     "best",
        //     address(bitpandaEcosystemToken)
        // );
        vm.writeJson(addresses, string.concat(blockchainName, ".json"));
    }

    function importContractAddresses() public {
        Blockchain memory blockchain = determineBlockchain();
        readContractAddresses(blockchain);
        registryFacet = PantosRegistryFacet(
            getContractAddress(blockchain, "registry_facet")
        );
        transferFacet = PantosTransferFacet(
            getContractAddress(blockchain, "transfer_facet")
        );
    }

    function deploy() public {
        vm.startBroadcast();
        registryFacet = deployRegistryFacet();
        transferFacet = deployTransferFacet();
        vm.stopBroadcast();
        exportContractAddresses();
    }

    function roleActions(address pantosHubProxyAddress) public {
        importContractAddresses();
        IPantosHub pantosHub = IPantosHub(pantosHubProxyAddress);

        // Ensuring PantosHub is paused at the time of diamond cut
        if (!pantosHub.paused()) {
            vm.broadcast(); // PAUSER
            pantosHub.pause();
            // console.log("PantosHub: paused=%s", pantosHub.paused());
        }

        vm.startBroadcast(); // SUPERCRITICAL OPS

        diamondCutUpgradeFacets(
            pantosHubProxyAddress,
            registryFacet,
            transferFacet
        );

        vm.stopBroadcast();
    }
}
