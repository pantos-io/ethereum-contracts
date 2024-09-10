// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";

import {IPantosHub} from "../src/interfaces/IPantosHub.sol";
import {PantosForwarder} from "../src/PantosForwarder.sol";
import {PantosToken} from "../src/PantosToken.sol";
import {BitpandaEcosystemToken} from "../src/BitpandaEcosystemToken.sol";
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
/**
 * @title DeployContracts
 *
 * @notice Deploy and initialize all the Pantos smart contracts on an
 * Ethereum-compatible single blockchain.
 *
 * @dev Usage
 * forge script ./script/DeployContracts.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force --sig \
 *     "run(address,address,address,address,address,uint256,uint256,uint256,address[])" \
 *     <validator> <pauser> <deployer> <mediumCriticalOps> <superCriticalOps> \
 *     <panSupply> <bestSupply> <nextTransferId> <otherValidators>
 */
contract DeployContracts is
    PantosHubDeployer,
    PantosForwarderDeployer,
    PantosWrapperDeployer,
    PantosTokenDeployer,
    BitpandaEcosystemTokenDeployer,
    AccessControllerDeployer
{
    PantosHubProxy public pantosHubProxy;
    PantosHubInit public pantosHubInit;
    PantosFacets public pantosFacets;
    PantosForwarder public pantosForwarder;
    PantosToken public pantosToken;
    BitpandaEcosystemToken public bitpandaEcosystemToken;
    AccessController public accessController;
    address public pauser;
    address public deployer;
    address public mediumCriticalOps;
    address public superCriticalOps;

    function exportContractAddresses() public {
        string memory blockchainName = determineBlockchain().name;
        string memory addresses;
        for (uint256 i; i < pantosWrappers.length; i++) {
            vm.serializeAddress(
                "addresses",
                pantosWrappers[i].symbol(),
                address(pantosWrappers[i])
            );
        }

        vm.serializeAddress("addresses", "hub_proxy", address(pantosHubProxy));
        vm.serializeAddress("addresses", "hub_init", address(pantosHubInit));
        vm.serializeAddress(
            "addresses",
            "diamond_cut_facet",
            address(pantosFacets.dCut)
        );
        vm.serializeAddress(
            "addresses",
            "diamond_loupe_facet",
            address(pantosFacets.dLoupe)
        );
        vm.serializeAddress(
            "addresses",
            "registry_facet",
            address(pantosFacets.registry)
        );
        vm.serializeAddress(
            "addresses",
            "transfer_facet",
            address(pantosFacets.transfer)
        );

        vm.serializeAddress(
            "addresses",
            "forwarder",
            address(pantosForwarder)
        );
        vm.serializeAddress("addresses", "pan", address(pantosToken));
        vm.serializeAddress(
            "addresses",
            "access_controller",
            address(accessController)
        );
        addresses = vm.serializeAddress(
            "addresses",
            "best",
            address(bitpandaEcosystemToken)
        );
        vm.writeJson(addresses, string.concat(blockchainName, ".json"));
    }

    function exportPantosRolesAddresses() public {
        string memory blockchainName = determineBlockchain().name;
        string memory roles;
        vm.serializeAddress("roles", "deployer", deployer);
        vm.serializeAddress("roles", "pauser", pauser);
        vm.serializeAddress("roles", "medium_critical_ops", mediumCriticalOps);
        roles = vm.serializeAddress(
            "roles",
            "super_critical_ops",
            superCriticalOps
        );
        vm.writeJson(roles, string.concat(blockchainName, "_ROLES.json"));
    }

    function importContractAddresses() public {
        Blockchain memory blockchain = determineBlockchain();
        readContractAddresses(blockchain);
        pantosHubProxy = PantosHubProxy(
            payable(getContractAddress(blockchain, "hub_proxy"))
        );
        pantosHubInit = PantosHubInit(
            getContractAddress(blockchain, "hub_init")
        );
        pantosForwarder = PantosForwarder(
            getContractAddress(blockchain, "forwarder")
        );
        pantosToken = PantosToken(getContractAddress(blockchain, "pan"));
        bitpandaEcosystemToken = BitpandaEcosystemToken(
            getContractAddress(blockchain, "best")
        );

        pantosFacets.dCut = DiamondCutFacet(
            getContractAddress(blockchain, "diamond_cut_facet")
        );
        pantosFacets.dLoupe = DiamondLoupeFacet(
            getContractAddress(blockchain, "diamond_loupe_facet")
        );
        pantosFacets.registry = PantosRegistryFacet(
            getContractAddress(blockchain, "registry_facet")
        );
        pantosFacets.transfer = PantosTransferFacet(
            getContractAddress(blockchain, "transfer_facet")
        );

        accessController = AccessController(
            getContractAddress(blockchain, "access_controller")
        );
    }

    function deploy(
        address pauser_,
        address deployer_,
        address mediumCriticalOps_,
        address superCriticalOps_,
        uint256 panSupply,
        uint256 bestSupply
    ) public {
        vm.startBroadcast();
        pauser = pauser_;
        deployer = deployer_;
        mediumCriticalOps = mediumCriticalOps_;
        superCriticalOps = superCriticalOps_;

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

        deployCoinWrappers(accessController);

        vm.stopBroadcast();

        exportContractAddresses();
        exportPantosRolesAddresses();
        // TODO export safe info and nonces
    }

    function roleActions(
        uint256 nextTransferId,
        address primaryValidator,
        address[] memory otherValidators
    ) public {
        importContractAddresses();
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
        initializePantosWrappers(pantosHub, pantosForwarder);
        vm.stopBroadcast();
    }
}
