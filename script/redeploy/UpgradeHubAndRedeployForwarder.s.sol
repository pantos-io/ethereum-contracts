// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {PantosRegistryFacet} from "../../src/facets/PantosRegistryFacet.sol";
import {PantosTransferFacet} from "../../src/facets/PantosTransferFacet.sol";
import {AccessController} from "../../src/access/AccessController.sol";
import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {PantosHubProxy} from "../../src/PantosHubProxy.sol";
import {PantosToken} from "../../src/PantosToken.sol";
import {PantosWrapper} from "../../src/PantosWrapper.sol";

import {PantosBaseAddresses} from "../helpers/PantosBaseAddresses.s.sol";
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
    PantosBaseAddresses,
    PantosHubDeployer,
    PantosForwarderRedeployer
{
    PantosHubProxy pantosHubProxy;
    PantosToken pantosToken;
    AccessController accessController;
    PantosForwarder oldForwarder;
    PantosWrapper[] tokens;

    PantosRegistryFacet newRegistryFacet;
    PantosTransferFacet newTransferFacet;
    PantosForwarder newPantosForwarder;

    function deploy(address accessControllerAddress) public {
        accessController = AccessController(accessControllerAddress);

        vm.startBroadcast();
        newRegistryFacet = deployRegistryFacet();
        newTransferFacet = deployTransferFacet();
        newPantosForwarder = deployPantosForwarder(accessController);
        vm.stopBroadcast();

        exportUpgradedContractAddresses();
    }

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

        // this will migrate new forwarder at pantosHub
        vm.startBroadcast(accessController.superCriticalOps());
        initializePantosHub(
            pantosHub,
            newPantosForwarder,
            pantosToken,
            pantosHub.getPrimaryValidatorNode()
        );
        vm.stopBroadcast();

        address[] memory validatorNodeAddresses = tryGetValidatorNodes(
            oldForwarder
        );

        vm.startBroadcast(accessController.superCriticalOps());
        initializePantosForwarder(
            newPantosForwarder,
            pantosHub,
            pantosToken,
            validatorNodeAddresses
        );
        vm.stopBroadcast();

        // Pause old forwarder
        vm.startBroadcast(accessController.pauser());
        pauseForwarder(oldForwarder);
        vm.stopBroadcast();

        // migrate new Forwarder at tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            if (!tokens[i].paused()) {
                vm.broadcast(accessController.pauser());
                tokens[i].pause();
            }
            vm.startBroadcast(accessController.superCriticalOps());
            migrateNewForwarderAtToken(newPantosForwarder, tokens[i]);
            vm.stopBroadcast();
        }
        overrideWithRedeployedAddresses();
    }

    function exportUpgradedContractAddresses() public {
        ContractAddress[] memory contractAddresses = new ContractAddress[](3);
        contractAddresses[0] = ContractAddress(
            Contract.REGISTRY_FACET,
            address(newRegistryFacet)
        );
        contractAddresses[1] = ContractAddress(
            Contract.TRANSFER_FACET,
            address(newTransferFacet)
        );
        contractAddresses[2] = ContractAddress(
            Contract.FORWARDER,
            address(newPantosForwarder)
        );
        exportContractAddresses(contractAddresses, true);
    }

    function importContractAddresses() public {
        readContractAddresses(thisBlockchain);
        readRedeployedContractAddresses();

        // New items
        newRegistryFacet = PantosRegistryFacet(
            getContractAddress(Contract.REGISTRY_FACET, true)
        );
        newTransferFacet = PantosTransferFacet(
            getContractAddress(Contract.TRANSFER_FACET, true)
        );
        newPantosForwarder = PantosForwarder(
            payable(getContractAddress(Contract.FORWARDER, true))
        );

        // Old items
        pantosToken = PantosToken(getContractAddress(Contract.PAN, false));

        pantosHubProxy = PantosHubProxy(
            payable(getContractAddress(Contract.HUB_PROXY, false))
        );
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        oldForwarder = PantosForwarder(
            getContractAddress(Contract.FORWARDER, false)
        );
        string[] memory tokenSymbols = getTokenSymbols();
        for (uint256 i = 0; i < tokenSymbols.length; i++) {
            Contract contract_ = _keysToContracts[tokenSymbols[i]];
            address token = getContractAddress(contract_, false);
            tokens.push(PantosWrapper(token));
        }
    }
}
