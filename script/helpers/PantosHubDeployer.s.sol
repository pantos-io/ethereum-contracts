// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";
import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@diamond/interfaces/IDiamondLoupe.sol";
import {IERC165} from "@diamond/interfaces/IERC165.sol";
import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";

import {PantosTypes} from "../../src/interfaces/PantosTypes.sol";
import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {IPantosRegistry} from "../../src/interfaces/IPantosRegistry.sol";
import {IPantosTransfer} from "../../src/interfaces/IPantosTransfer.sol";
import {PantosRegistryFacet} from "../../src/facets/PantosRegistryFacet.sol";
import {PantosTransferFacet} from "../../src/facets/PantosTransferFacet.sol";
import {DiamondCutFacet} from "../../src/facets/DiamondCutFacet.sol";
import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {PantosToken} from "../../src/PantosToken.sol";
import {PantosHubProxy} from "../../src/PantosHubProxy.sol";
import {PantosHubInit} from "../../src/upgradeInitializers/PantosHubInit.sol";
import {AccessController} from "../../src/access/AccessController.sol";

import {PantosBaseScript} from "./PantosBaseScript.s.sol";
import {Constants} from "./Constants.s.sol";

struct PantosFacets {
    DiamondCutFacet dCut;
    DiamondLoupeFacet dLoupe;
    PantosRegistryFacet registry;
    PantosTransferFacet transfer;
}

abstract contract PantosHubDeployer is PantosBaseScript {
    function deployRegistryFacet() public returns (PantosRegistryFacet) {
        PantosRegistryFacet registryFacet = new PantosRegistryFacet();
        console.log(
            "PantosRegistryFacet deployed; address=%s",
            address(registryFacet)
        );
        return registryFacet;
    }

    function deployTransferFacet() public returns (PantosTransferFacet) {
        PantosTransferFacet transferFacet = new PantosTransferFacet();
        console.log(
            "PantosTransferFacet deployed; address=%s",
            address(transferFacet)
        );
        return transferFacet;
    }

    function deployPantosHub(
        AccessController accessController
    ) public returns (PantosHubProxy, PantosHubInit, PantosFacets memory) {
        DiamondCutFacet dCutFacet = new DiamondCutFacet();
        console.log(
            "DiamondCutFacet deployed; address=%s",
            address(dCutFacet)
        );

        PantosHubProxy pantosHubDiamond = new PantosHubProxy(
            address(dCutFacet),
            address(accessController)
        );
        console.log(
            "PantosHubProxy deployed; address=%s; accessController=%s",
            address(pantosHubDiamond),
            address(accessController)
        );

        // deploying all other facets
        DiamondLoupeFacet dLoupe = new DiamondLoupeFacet();
        console.log("DiamondLoupeFacet deployed; address=%s", address(dLoupe));
        PantosRegistryFacet registryFacet = deployRegistryFacet();
        PantosTransferFacet transferFacet = deployTransferFacet();

        PantosFacets memory pantosFacets = PantosFacets({
            dCut: dCutFacet,
            dLoupe: dLoupe,
            registry: registryFacet,
            transfer: transferFacet
        });

        // deploy initializer
        PantosHubInit pantosHubInit = new PantosHubInit();
        console.log(
            "PantosHubInit deployed; address=%s",
            address(pantosHubInit)
        );
        return (pantosHubDiamond, pantosHubInit, pantosFacets);
    }

    // PantosRoles.DEPLOYER
    function diamondCutFacets(
        PantosHubProxy pantosHubProxy,
        PantosHubInit pantosHubInit,
        PantosFacets memory pantosFacets,
        uint256 nextTransferId
    ) public {
        // // Prepare diamond cut and initializer data
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts(pantosFacets);
        bytes memory initializerData = prepareInitializerData(nextTransferId);

        // upgrade pantosHub diamond with facets using diamondCut
        IDiamondCut(address(pantosHubProxy)).diamondCut(
            cut,
            address(pantosHubInit),
            initializerData
        );

        // wrap in IPantosHub ABI to support easier calls
        IPantosHub pantosHub = IPantosHub(address(pantosHubProxy));

        console.log(
            "diamondCut PantosHubProxy; paused=%s; cut(s) count=%s",
            pantosHub.paused(),
            cut.length
        );
    }

    // Prepare cut struct for all the facets
    function prepareFacetCuts(
        PantosFacets memory facets
    ) public pure returns (IDiamondCut.FacetCut[] memory) {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);

        // DiamondLoupeFacet
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(facets.dLoupe),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getDiamondLoupeSelectors()
        });

        // PantosRegistryFacet
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(facets.registry),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getPantosRegistrySelectors()
        });

        // PantosTransferFacet
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(facets.transfer),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getPantosTransferSelectors()
        });
        return cut;
    }

    // initializing PantosHub storage using one-off helper contract
    function prepareInitializerData(
        uint nextTransferId
    ) public returns (bytes memory) {
        Blockchain memory blockchain = determineBlockchain();
        PantosHubInit.Args memory args = PantosHubInit.Args({
            blockchainId: uint256(blockchain.blockchainId),
            blockchainName: blockchain.name,
            minimumServiceNodeDeposit: Constants.MINIMUM_SERVICE_NODE_DEPOSIT,
            unbondingPeriodServiceNodeDeposit: Constants
                .SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD,
            validatorFeeFactor: blockchain.feeFactor,
            parameterUpdateDelay: Constants.PARAMETER_UPDATE_DELAY,
            nextTransferId: nextTransferId
        });
        bytes memory initializerData = abi.encodeCall(
            PantosHubInit.init,
            (args)
        );
        return initializerData;
    }

    // PantosRoles.SUPER_CRITICAL_OPS  and expects PantosHub is paused
    function initializePantosHub(
        IPantosHub pantosHub,
        PantosForwarder pantosForwarder,
        PantosToken pantosToken,
        address primaryValidatorNodeAddress
    ) public {
        require(
            pantosHub.paused(),
            "PantosHub should be paused before initializePantosHub"
        );

        // Set the forwarder, PAN token, and primary validator node
        // addresses
        address currentForwarder = pantosHub.getPantosForwarder();
        if (currentForwarder != address(pantosForwarder)) {
            pantosHub.setPantosForwarder(address(pantosForwarder));
            console.log(
                "PantosHub.setPantosForwarder(%s)",
                address(pantosForwarder)
            );
        } else {
            console.log(
                "PantosHub: PantosForwarder already set, "
                "skipping setPantosForwarder(%s)",
                address(pantosForwarder)
            );
        }

        address currentPantosToken = pantosHub.getPantosToken();
        if (currentPantosToken != address(pantosToken)) {
            pantosHub.setPantosToken(address(pantosToken));
            console.log("PantosHub.setPantosToken(%s)", address(pantosToken));
        } else {
            console.log(
                "PantosHub: PantosToken already set, "
                "skipping setPantosToken(%s)",
                address(pantosToken)
            );
        }

        address currentPrimaryNode = pantosHub.getPrimaryValidatorNode();
        if (currentPrimaryNode != primaryValidatorNodeAddress) {
            pantosHub.setPrimaryValidatorNode(primaryValidatorNodeAddress);
            console.log(
                "PantosHub.setPrimaryValidatorNode(%s)",
                primaryValidatorNodeAddress
            );
        } else {
            console.log(
                "PantosHub: Primary Validator already set, "
                "skipping setPrimaryValidatorNode(%s)",
                primaryValidatorNodeAddress
            );
        }

        Blockchain memory blockchain = determineBlockchain();

        // Register the other blockchains
        for (uint256 i; i < getBlockchainsLength(); i++) {
            Blockchain memory otherBlockchain = getBlockchainById(
                BlockchainId(i)
            );

            if (
                otherBlockchain.blockchainId != blockchain.blockchainId &&
                !otherBlockchain.skip
            ) {
                PantosTypes.BlockchainRecord
                    memory blockchainRecord = pantosHub.getBlockchainRecord(
                        uint256(otherBlockchain.blockchainId)
                    );
                if (!blockchainRecord.active) {
                    pantosHub.registerBlockchain(
                        uint256(otherBlockchain.blockchainId),
                        otherBlockchain.name,
                        otherBlockchain.feeFactor
                    );
                    console.log(
                        "PantosHub.registerBlockchain(%s) on %s",
                        otherBlockchain.name,
                        blockchain.name
                    );
                } else if (
                    keccak256(abi.encodePacked(blockchainRecord.name)) !=
                    keccak256(abi.encodePacked(otherBlockchain.name))
                ) {
                    console.log(
                        "PantosHub: blockchain names do not match. "
                        "Unregister and register again "
                        "Old name: %s New name: %s",
                        blockchainRecord.name,
                        otherBlockchain.name
                    );
                    pantosHub.unregisterBlockchain(
                        uint256(otherBlockchain.blockchainId)
                    );
                    pantosHub.registerBlockchain(
                        uint256(otherBlockchain.blockchainId),
                        otherBlockchain.name,
                        otherBlockchain.feeFactor
                    );
                    console.log(
                        "PantosHub.unregisterBlockchain(%s), "
                        "PantosHub.registerBlockchain(%s), ",
                        uint256(otherBlockchain.blockchainId),
                        uint256(otherBlockchain.blockchainId)
                    );
                } else {
                    console.log(
                        "PantosHub: Blockchain %s already registered "
                        "Skipping registerBlockchain(%s)",
                        otherBlockchain.name,
                        uint256(otherBlockchain.blockchainId)
                    );
                }
            }
        }
        // Unpause the hub contract after initialization
        pantosHub.unpause();
        console.log("PantosHub initialized; paused=%s", pantosHub.paused());
    }

    // PantosRoles.DEPLOYER and expects PantosHub is paused already
    function diamondCutUpgradeFacets(
        address pantosHubProxyAddress,
        PantosRegistryFacet registryFacet,
        PantosTransferFacet transferFacet
    ) public {
        // Prepare diamond cut
        IDiamondCut.FacetCut[] memory cut = preparePantosHubUpgradeFacetCuts(
            pantosHubProxyAddress,
            registryFacet,
            transferFacet
        );

        IPantosHub pantosHub = IPantosHub(pantosHubProxyAddress);
        // Ensuring PantosHub is paused at the time of diamond cut
        require(
            pantosHub.paused(),
            "PantosHub should be paused before diamondCut"
        );

        // upgrade pantosHub diamond with facets using diamondCut
        IDiamondCut(pantosHubProxyAddress).diamondCut(cut, address(0), "");

        console.log(
            "diamondCut PantosHubProxy; paused=%s; cut(s) count=%s;",
            pantosHub.paused(),
            cut.length
        );
    }

    function getUpgradeFacetCut(
        address newFacetAddress,
        bytes4[] memory newSelectors,
        bytes4[] memory oldSelectors
    ) public view returns (IDiamondCut.FacetCut[] memory) {
        bytes4 oldInterfaceId = _calculateInterfaceId(oldSelectors);
        bytes4 newInterfaceId = _calculateInterfaceId(newSelectors);

        if (oldInterfaceId == newInterfaceId) {
            console.log(
                "No interface change in new facet address=%s; Using Replace"
                " cut",
                newFacetAddress
            );
            IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
            cut[0] = IDiamondCut.FacetCut({
                facetAddress: address(newFacetAddress),
                action: IDiamondCut.FacetCutAction.Replace,
                functionSelectors: newSelectors
            });
            return cut;
        } else {
            console.log(
                "Interface change detected in new facet address=%s;"
                " Using Remove/Add cut",
                newFacetAddress
            );

            IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](2);
            cut[0] = IDiamondCut.FacetCut({
                facetAddress: address(0),
                action: IDiamondCut.FacetCutAction.Remove,
                functionSelectors: oldSelectors
            });
            cut[1] = IDiamondCut.FacetCut({
                facetAddress: address(newFacetAddress),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: newSelectors
            });
            return cut;
        }
    }

    /**
     * @dev This method tries to get old facet address via loupe by using one of
     * the existing function selector. If used function selector is getting
     * replaced, then use any other existing function selector.
     */
    function preparePantosHubUpgradeFacetCuts(
        address pantosHubProxyAddress,
        PantosRegistryFacet _pantosRegistryFacet,
        PantosTransferFacet _pantosTransferFacet
    ) private view returns (IDiamondCut.FacetCut[] memory) {
        address registryAddressOld = IDiamondLoupe(pantosHubProxyAddress)
            .facetAddress(IPantosRegistry.registerBlockchain.selector);
        require(
            registryAddressOld != address(0),
            "Failed to find registry facet of provided selector."
            " Provide a selector which is present in the current facet."
        );
        console.log(
            "Found current registry facet address=%s;",
            registryAddressOld
        );

        bytes4[] memory regiatrySelectorsOld = IDiamondLoupe(
            pantosHubProxyAddress
        ).facetFunctionSelectors(registryAddressOld);
        bytes4[] memory registrySelectorsNew = getPantosRegistrySelectors();

        IDiamondCut.FacetCut[] memory cutRegistry = getUpgradeFacetCut(
            address(_pantosRegistryFacet),
            registrySelectorsNew,
            regiatrySelectorsOld
        );

        address transferAddressOld = IDiamondLoupe(pantosHubProxyAddress)
            .facetAddress(IPantosTransfer.transfer.selector);
        require(
            transferAddressOld != address(0),
            "Failed to find transfer facet of provided selector"
        );

        console.log(
            "Found current transfer facet address=%s;",
            transferAddressOld
        );

        bytes4[] memory transferSelectorsOld = IDiamondLoupe(
            pantosHubProxyAddress
        ).facetFunctionSelectors(transferAddressOld);
        bytes4[] memory transferSelectorsNew = getPantosTransferSelectors();

        IDiamondCut.FacetCut[] memory cutTransfer = getUpgradeFacetCut(
            address(_pantosTransferFacet),
            transferSelectorsNew,
            transferSelectorsOld
        );

        // combining cuts for both facets in a single array
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](
            cutRegistry.length + cutTransfer.length
        );

        for (uint i; i < cutRegistry.length; i++) {
            cut[i] = cutRegistry[i];
        }

        for (uint i; i < cutTransfer.length; i++) {
            cut[cutRegistry.length + i] = cutTransfer[i];
        }
        return cut;
    }

    function pausePantosHub(IPantosHub pantosHub) public {
        if (!pantosHub.paused()) {
            pantosHub.pause();
            console.log(
                "PantosHub(%s): paused=%s",
                address(pantosHub),
                pantosHub.paused()
            );
        }
    }

    function _calculateInterfaceId(
        bytes4[] memory selectors
    ) private pure returns (bytes4) {
        bytes4 id = bytes4(0);
        for (uint i; i < selectors.length; i++) {
            id = id ^ selectors[i];
        }
        return id;
    }

    function getPantosRegistrySelectors()
        public
        pure
        returns (bytes4[] memory)
    {
        bytes4[] memory selectors = new bytes4[](50);
        uint i = 0;

        selectors[i++] = IPantosRegistry.setPantosForwarder.selector;
        selectors[i++] = IPantosRegistry.setPantosToken.selector;
        selectors[i++] = IPantosRegistry.setPrimaryValidatorNode.selector;
        selectors[i++] = IPantosRegistry.registerBlockchain.selector;
        selectors[i++] = IPantosRegistry.unregisterBlockchain.selector;
        selectors[i++] = IPantosRegistry.updateBlockchainName.selector;
        selectors[i++] = IPantosRegistry
            .initiateValidatorFeeFactorUpdate
            .selector;
        selectors[i++] = IPantosRegistry
            .executeValidatorFeeFactorUpdate
            .selector;
        selectors[i++] = IPantosRegistry
            .initiateUnbondingPeriodServiceNodeDepositUpdate
            .selector;
        selectors[i++] = IPantosRegistry
            .executeUnbondingPeriodServiceNodeDepositUpdate
            .selector;
        selectors[i++] = IPantosRegistry
            .initiateMinimumServiceNodeDepositUpdate
            .selector;
        selectors[i++] = IPantosRegistry
            .executeMinimumServiceNodeDepositUpdate
            .selector;
        selectors[i++] = IPantosRegistry
            .initiateParameterUpdateDelayUpdate
            .selector;
        selectors[i++] = IPantosRegistry
            .executeParameterUpdateDelayUpdate
            .selector;
        selectors[i++] = IPantosRegistry.registerToken.selector;
        selectors[i++] = IPantosRegistry.unregisterToken.selector;
        selectors[i++] = IPantosRegistry.registerExternalToken.selector;
        selectors[i++] = IPantosRegistry.unregisterExternalToken.selector;
        selectors[i++] = IPantosRegistry.registerServiceNode.selector;
        selectors[i++] = IPantosRegistry.unregisterServiceNode.selector;
        selectors[i++] = IPantosRegistry.withdrawServiceNodeDeposit.selector;
        selectors[i++] = IPantosRegistry
            .cancelServiceNodeUnregistration
            .selector;
        selectors[i++] = IPantosRegistry.increaseServiceNodeDeposit.selector;
        selectors[i++] = IPantosRegistry.decreaseServiceNodeDeposit.selector;
        selectors[i++] = IPantosRegistry.updateServiceNodeUrl.selector;

        selectors[i++] = IPantosRegistry.getPantosForwarder.selector;
        selectors[i++] = IPantosRegistry.getPantosToken.selector;
        selectors[i++] = IPantosRegistry.getPrimaryValidatorNode.selector;
        selectors[i++] = IPantosRegistry.getNumberBlockchains.selector;
        selectors[i++] = IPantosRegistry.getNumberActiveBlockchains.selector;
        selectors[i++] = IPantosRegistry.getCurrentBlockchainId.selector;
        selectors[i++] = IPantosRegistry.getBlockchainRecord.selector;
        selectors[i++] = IPantosRegistry
            .isServiceNodeInTheUnbondingPeriod
            .selector;
        selectors[i++] = IPantosRegistry.isValidValidatorNodeNonce.selector;
        selectors[i++] = IPantosRegistry
            .getCurrentMinimumServiceNodeDeposit
            .selector;
        selectors[i++] = IPantosRegistry.getMinimumServiceNodeDeposit.selector;
        selectors[i++] = IPantosRegistry
            .getCurrentUnbondingPeriodServiceNodeDeposit
            .selector;
        selectors[i++] = IPantosRegistry
            .getUnbondingPeriodServiceNodeDeposit
            .selector;
        selectors[i++] = IPantosRegistry.getTokens.selector;
        selectors[i++] = IPantosRegistry.getTokenRecord.selector;
        selectors[i++] = IPantosRegistry.getExternalTokenRecord.selector;
        selectors[i++] = IPantosRegistry.getServiceNodes.selector;
        selectors[i++] = IPantosRegistry.getServiceNodeRecord.selector;
        selectors[i++] = IPantosRegistry.getCurrentValidatorFeeFactor.selector;
        selectors[i++] = IPantosRegistry.getValidatorFeeFactor.selector;
        selectors[i++] = IPantosRegistry
            .getCurrentParameterUpdateDelay
            .selector;
        selectors[i++] = IPantosRegistry.getParameterUpdateDelay.selector;

        selectors[i++] = IPantosRegistry.pause.selector;
        selectors[i++] = IPantosRegistry.unpause.selector;
        selectors[i++] = IPantosRegistry.paused.selector;

        require(
            _calculateInterfaceId(selectors) ==
                type(IPantosRegistry).interfaceId,
            " Interface has changed, update getPantosRegistrySelectors()"
        );
        return selectors;
    }

    function getPantosTransferSelectors()
        public
        pure
        returns (bytes4[] memory)
    {
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = IPantosTransfer.transfer.selector;
        selectors[1] = IPantosTransfer.transferFrom.selector;
        selectors[2] = IPantosTransfer.transferTo.selector;
        selectors[3] = IPantosTransfer.isValidSenderNonce.selector;
        selectors[4] = IPantosTransfer.verifyTransfer.selector;
        selectors[5] = IPantosTransfer.verifyTransferFrom.selector;
        selectors[6] = IPantosTransfer.verifyTransferTo.selector;
        selectors[7] = IPantosTransfer.getNextTransferId.selector;

        require(
            _calculateInterfaceId(selectors) ==
                type(IPantosTransfer).interfaceId,
            " Interface has changed, update getPantosTransferSelectors()"
        );
        return selectors;
    }

    function getDiamondLoupeSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = IDiamondLoupe.facetAddress.selector;
        selectors[1] = IDiamondLoupe.facetAddresses.selector;
        selectors[2] = IDiamondLoupe.facetFunctionSelectors.selector;
        selectors[3] = IDiamondLoupe.facets.selector;
        selectors[4] = IERC165.supportsInterface.selector;
        return selectors;
    }
}
