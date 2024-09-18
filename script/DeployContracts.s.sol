// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";

import {IPantosHub} from "../src/interfaces/IPantosHub.sol";
import {PantosForwarder} from "../src/PantosForwarder.sol";
import {PantosToken} from "../src/PantosToken.sol";
import {BitpandaEcosystemToken} from "../src/BitpandaEcosystemToken.sol";
import {PantosWrapper} from "../src/PantosWrapper.sol";
import {AccessController} from "../src/access/AccessController.sol";
import {PantosHubProxy} from "../src/PantosHubProxy.sol";
import {PantosHubInit} from "../src/upgradeInitializers/PantosHubInit.sol";
import {PantosRegistryFacet} from "../src/facets/PantosRegistryFacet.sol";
import {PantosTransferFacet} from "../src/facets/PantosTransferFacet.sol";
import {DiamondCutFacet} from "../src/facets/DiamondCutFacet.sol";

import {PantosHubDeployer, PantosFacets} from "./helpers/PantosHubDeployer.s.sol";
import {PantosForwarderDeployer} from "./helpers/PantosForwarderDeployer.s.sol";
import {PantosWrapperDeployer} from "./helpers/PantosWrapperDeployer.s.sol";
import {PantosTokenDeployer} from "./helpers/PantosTokenDeployer.s.sol";
import {BitpandaEcosystemTokenDeployer} from "./helpers/BitpandaEcosystemTokenDeployer.s.sol";
import {AccessControllerDeployer} from "./helpers/AccessControllerDeployer.s.sol";
import {PantosBaseAddresses} from "./helpers/PantosBaseAddresses.s.sol";
import {SafeAddresses} from "./helpers/SafeAddresses.s.sol";
/**
 * @title DeployContracts
 *
 * @notice Deploy and initialize all the Pantos smart contracts on an
 * Ethereum-compatible single blockchain.
 *
 * @dev Usage
 * 1. Deploy by any gas paying account:
 * forge script ./script/DeployContracts.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force --sig \
 *     "deploy(uint256,uint256)" <panSupply> <bestSupply>
 *
 * 2. Simulate roleActions to be later signed by appropriate roles
 * forge script ./script/DeployContracts.s.sol --rpc-url <rpc alias> \
 *          -vvvv --sig "roleActions(uint256,address,address[])" \
 *          <nextTransferId>  <primaryValidator> <otherValidators>
 */
contract DeployContracts is
    PantosBaseAddresses,
    SafeAddresses,
    PantosHubDeployer,
    PantosForwarderDeployer,
    PantosWrapperDeployer,
    PantosTokenDeployer,
    BitpandaEcosystemTokenDeployer,
    AccessControllerDeployer
{
    AccessController accessController;
    PantosHubProxy pantosHubProxy;
    PantosHubInit pantosHubInit;
    PantosFacets pantosFacets;
    PantosForwarder pantosForwarder;
    PantosToken pantosToken;
    BitpandaEcosystemToken bitpandaEcosystemToken;
    PantosWrapper[] pantosWrappers;

    function deploy(uint256 panSupply, uint256 bestSupply) public {
        vm.startBroadcast();
        readRoleAddresses();
        address pauser = getRoleAddress(Role.PAUSER);
        address deployer = getRoleAddress(Role.DEPLOYER);
        address mediumCriticalOps = getRoleAddress(Role.MEDIUM_CRITICAL_OPS);
        address superCriticalOps = getRoleAddress(Role.SUPER_CRITICAL_OPS);
        accessController = deployAccessController(
            pauser,
            deployer,
            mediumCriticalOps,
            superCriticalOps
        );
        (pantosHubProxy, pantosHubInit, pantosFacets) = deployPantosHub(
            accessController
        );
        pantosForwarder = deployPantosForwarder(accessController);
        pantosToken = deployPantosToken(panSupply, accessController);
        bitpandaEcosystemToken = deployBitpandaEcosystemToken(
            bestSupply,
            accessController
        );
        pantosWrappers = deployCoinWrappers(accessController);
        vm.stopBroadcast();

        exportAllContractAddresses();
    }

    function roleActions(
        uint256 nextTransferId,
        address primaryValidator,
        address[] memory otherValidators
    ) public {
        importAllContractAddresses();
        vm.broadcast(accessController.deployer());
        diamondCutFacets(
            pantosHubProxy,
            pantosHubInit,
            pantosFacets,
            nextTransferId
        );

        IPantosHub pantosHub = IPantosHub(address(pantosHubProxy));

        vm.startBroadcast(accessController.superCriticalOps());
        initializePantosHub(
            pantosHub,
            pantosForwarder,
            pantosToken,
            primaryValidator
        );

        // all validator node addresses
        address[] memory validatorNodeAddresses = new address[](
            otherValidators.length + 1
        );
        validatorNodeAddresses[0] = primaryValidator;
        for (uint i; i < otherValidators.length; i++) {
            validatorNodeAddresses[i + 1] = otherValidators[i];
        }

        initializePantosForwarder(
            pantosForwarder,
            pantosHub,
            pantosToken,
            validatorNodeAddresses
        );
        initializePantosToken(pantosToken, pantosForwarder);
        initializeBitpandaEcosystemToken(
            bitpandaEcosystemToken,
            pantosHub,
            pantosForwarder
        );
        initializePantosWrappers(pantosHub, pantosForwarder, pantosWrappers);
        vm.stopBroadcast();
        writeAllSafeInfo(accessController);
    }

    function exportAllContractAddresses() internal {
        ContractAddress[] memory contractAddresses = new ContractAddress[](
            10 + pantosWrappers.length
        );
        contractAddresses[0] = ContractAddress(
            Contract.ACCESS_CONTROLLER,
            address(accessController)
        );
        contractAddresses[1] = ContractAddress(
            Contract.HUB_PROXY,
            address(pantosHubProxy)
        );
        contractAddresses[2] = ContractAddress(
            Contract.HUB_INIT,
            address(pantosHubInit)
        );
        contractAddresses[3] = ContractAddress(
            Contract.DIAMOND_CUT_FACET,
            address(pantosFacets.dCut)
        );
        contractAddresses[4] = ContractAddress(
            Contract.DIAMOND_LOUPE_FACET,
            address(pantosFacets.dLoupe)
        );
        contractAddresses[5] = ContractAddress(
            Contract.REGISTRY_FACET,
            address(pantosFacets.registry)
        );
        contractAddresses[6] = ContractAddress(
            Contract.TRANSFER_FACET,
            address(pantosFacets.transfer)
        );
        contractAddresses[7] = ContractAddress(
            Contract.FORWARDER,
            address(pantosForwarder)
        );
        contractAddresses[8] = ContractAddress(
            Contract.PAN,
            address(pantosToken)
        );
        contractAddresses[9] = ContractAddress(
            Contract.BEST,
            address(bitpandaEcosystemToken)
        );
        for (uint i; i < pantosWrappers.length; i++) {
            contractAddresses[i + 10] = ContractAddress(
                _keysToContracts[pantosWrappers[i].symbol()],
                address(pantosWrappers[i])
            );
        }
        exportContractAddresses(contractAddresses, false);
    }

    function importAllContractAddresses() internal {
        readContractAddresses(determineBlockchain());

        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        pantosHubProxy = PantosHubProxy(
            payable(getContractAddress(Contract.HUB_PROXY, false))
        );
        pantosHubInit = PantosHubInit(
            getContractAddress(Contract.HUB_INIT, false)
        );
        pantosFacets = PantosFacets(
            DiamondCutFacet(
                getContractAddress(Contract.DIAMOND_CUT_FACET, false)
            ),
            DiamondLoupeFacet(
                getContractAddress(Contract.DIAMOND_LOUPE_FACET, false)
            ),
            PantosRegistryFacet(
                getContractAddress(Contract.REGISTRY_FACET, false)
            ),
            PantosTransferFacet(
                getContractAddress(Contract.TRANSFER_FACET, false)
            )
        );
        pantosForwarder = PantosForwarder(
            getContractAddress(Contract.FORWARDER, false)
        );
        pantosToken = PantosToken(getContractAddress(Contract.PAN, false));
        bitpandaEcosystemToken = BitpandaEcosystemToken(
            getContractAddress(Contract.BEST, false)
        );
        pantosWrappers = new PantosWrapper[](7);
        pantosWrappers[0] = PantosWrapper(
            getContractAddress(Contract.PAN_AVAX, false)
        );
        pantosWrappers[1] = PantosWrapper(
            getContractAddress(Contract.PAN_BNB, false)
        );
        pantosWrappers[2] = PantosWrapper(
            getContractAddress(Contract.PAN_CELO, false)
        );
        pantosWrappers[3] = PantosWrapper(
            getContractAddress(Contract.PAN_CRO, false)
        );
        pantosWrappers[4] = PantosWrapper(
            getContractAddress(Contract.PAN_ETH, false)
        );
        pantosWrappers[5] = PantosWrapper(
            getContractAddress(Contract.PAN_FTM, false)
        );
        pantosWrappers[6] = PantosWrapper(
            getContractAddress(Contract.PAN_MATIC, false)
        );
    }
}
