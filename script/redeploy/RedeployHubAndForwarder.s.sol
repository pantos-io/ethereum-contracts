// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";
import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";

import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {AccessController} from "../../src/access/AccessController.sol";
import {PantosHubProxy} from "../../src/PantosHubProxy.sol";
import {PantosHubInit} from "../../src/upgradeInitializers/PantosHubInit.sol";
import {PantosToken} from "../../src/PantosToken.sol";
import {DiamondCutFacet} from "../../src/facets/DiamondCutFacet.sol";
import {PantosRegistryFacet} from "../../src/facets/PantosRegistryFacet.sol";
import {PantosTransferFacet} from "../../src/facets/PantosTransferFacet.sol";
import {PantosWrapper} from "../../src/PantosWrapper.sol";

import {PantosBaseAddresses} from "../helpers/PantosBaseAddresses.s.sol";
import {PantosForwarderRedeployer} from "../helpers/PantosForwarderRedeployer.s.sol";
import {PantosHubRedeployer} from "../helpers/PantosHubRedeployer.s.sol";
import {PantosFacets} from "../helpers/PantosHubDeployer.s.sol";
import {SafeAddresses} from "../helpers/SafeAddresses.s.sol";

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
 * 1. Deploy by any gas paying account:
 * forge script ./script/redeploy/RedeployHubAndForwarder.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "deploy(address)" <accessControllerAddress>
 * 2. Simulate roleActions to be later signed by appropriate roles
 * forge script ./script/redeploy/RedeployHubAndForwarder.s.sol \
 * --rpc-url <rpc alias> --sig "roleActions() -vvvv"
 */
contract RedeployHubAndForwarder is
    PantosBaseAddresses,
    SafeAddresses,
    PantosHubRedeployer,
    PantosForwarderRedeployer
{
    AccessController accessController;
    PantosHubProxy newPantosHubProxy;
    PantosHubInit newPantosHubInit;
    PantosFacets newPantosFacets;
    PantosForwarder newPantosForwarder;
    IPantosHub oldPantosHub;
    PantosWrapper[] tokens;

    function deploy(address accessControllerAddress) public {
        accessController = AccessController(accessControllerAddress);

        vm.startBroadcast();
        (
            newPantosHubProxy,
            newPantosHubInit,
            newPantosFacets
        ) = deployPantosHub(accessController);

        newPantosForwarder = deployPantosForwarder(accessController);
        exportRedeployedContractAddresses();
    }

    function roleActions() public {
        importContractAddresses();

        initializePantosHubRedeployer(oldPantosHub);
        uint256 nextTransferId = oldPantosHub.getNextTransferId();
        uint256 commitmentWaitPeriod = oldPantosHub.getCommitmentWaitPeriod();
        PantosForwarder oldForwarder = PantosForwarder(
            oldPantosHub.getPantosForwarder()
        );

        vm.startBroadcast(accessController.pauser());
        pausePantosHub(oldPantosHub);
        pauseForwarder(oldForwarder);
        vm.stopBroadcast();

        vm.broadcast(accessController.deployer());
        diamondCutFacets(
            newPantosHubProxy,
            newPantosHubInit,
            newPantosFacets,
            nextTransferId
        );

        IPantosHub newPantosHub = IPantosHub(address(newPantosHubProxy));
        PantosToken pantosToken = PantosToken(oldPantosHub.getPantosToken());

        vm.broadcast(accessController.superCriticalOps());
        initializePantosHub(
            newPantosHub,
            newPantosForwarder,
            pantosToken,
            oldPantosHub.getPrimaryValidatorNode(),
            commitmentWaitPeriod
        );

        uint256 minimumValidatorNodeSignatures = tryGetMinimumValidatorNodeSignatures(
                oldForwarder
            );
        address[] memory validatorNodeAddresses = tryGetValidatorNodes(
            oldForwarder
        );

        vm.broadcast(accessController.superCriticalOps());
        initializePantosForwarder(
            newPantosForwarder,
            newPantosHub,
            pantosToken,
            minimumValidatorNodeSignatures,
            validatorNodeAddresses
        );

        // Pause old forwarder
        vm.broadcast(accessController.pauser());
        pauseForwarder(oldForwarder);

        // Migrate
        vm.broadcast(accessController.superCriticalOps());
        migrateTokensFromOldHubToNewHub(newPantosHub);

        // migrate new Forwarder at tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.startBroadcast(accessController.pauser());
            tokens[i].pause();

            vm.broadcast(accessController.superCriticalOps());
            migrateNewForwarderAtToken(newPantosForwarder, tokens[i]);
        }

        overrideWithRedeployedAddresses();
        writeAllSafeInfo(accessController);
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
        contractAddresses[5] = ContractAddress(
            Contract.FORWARDER,
            address(newPantosForwarder)
        );
        exportContractAddresses(contractAddresses, true);
    }

    function importContractAddresses() public {
        readContractAddresses(determineBlockchain());
        readRedeployedContractAddresses();

        // New items
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

        newPantosForwarder = PantosForwarder(
            payable(getContractAddress(Contract.FORWARDER, true))
        );

        // Old items
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );

        oldPantosHub = IPantosHub(
            payable(getContractAddress(Contract.HUB_PROXY, false))
        );

        string[] memory tokenSymbols = getTokenSymbols();
        for (uint256 i = 0; i < tokenSymbols.length; i++) {
            Contract contract_ = _keysToContracts[tokenSymbols[i]];
            address token = getContractAddress(contract_, false);
            tokens.push(PantosWrapper(token));
        }
    }
}
