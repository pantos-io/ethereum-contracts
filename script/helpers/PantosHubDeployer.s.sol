// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;


/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";
import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@diamond/interfaces/IDiamondLoupe.sol";
import {IERC165} from "@diamond/interfaces/IERC165.sol";
import {IERC173} from "@diamond/interfaces/IERC173.sol";
import {DiamondCutFacet} from "@diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "@diamond/facets/OwnershipFacet.sol";

import {PantosTypes} from "../../src/interfaces/PantosTypes.sol";
import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {IPantosRegistry} from "../../src/interfaces/IPantosRegistry.sol";
import {IPantosTransfer} from "../../src/interfaces/IPantosTransfer.sol";
import {PantosRegistryFacet} from "../../src/facets/PantosRegistryFacet.sol";
import {PantosTransferFacet} from "../../src/facets/PantosTransferFacet.sol";
import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {PantosToken} from "../../src/PantosToken.sol";
import {PantosHubProxy} from "../../src/PantosHubProxy.sol";
import {PantosHubInit} from "../../src/upgradeInitializers/PantosHubInit.sol";

import {PantosBaseScript} from "./PantosBaseScript.s.sol";
import {Constants} from "./Constants.s.sol";
import {PantosBaseScript} from "./PantosBaseScript.s.sol";

struct DeployedFacets {
    DiamondCutFacet dCut;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet owner;
    PantosRegistryFacet registry;
    PantosTransferFacet transfer;
}

abstract contract PantosHubDeployer is PantosBaseScript {
    function deployPantosHub()
        public
        returns (IPantosHub, DeployedFacets memory)
    {
        // This will only change if we migrate testnets
        uint256 nextTransferId = 0;
        return deployPantosHub(nextTransferId);
    }

    function deployPantosHub(
        uint256 nextTransferId
    ) public returns (IPantosHub, DeployedFacets memory) {
        DiamondCutFacet dCutFacet = new DiamondCutFacet();
        console2.log(
            "DiamondCutFacet deployed; address=%s",
            address(dCutFacet)
        );

        PantosHubProxy pantosHubDiamond = new PantosHubProxy(
            address(msg.sender),
            address(dCutFacet)
        );

        console2.log(
            "PantosHubProxy deployed; address=%s",
            address(pantosHubDiamond)
        );

        // deploying all other facets
        DiamondLoupeFacet dLoupe = new DiamondLoupeFacet();
        console2.log(
            "DiamondLoupeFacet deployed; address=%s",
            address(dLoupe)
        );
        OwnershipFacet ownerFacet = new OwnershipFacet();
        console2.log(
            "OwnershipFacet deployed; address=%s",
            address(ownerFacet)
        );
        PantosRegistryFacet registryFacet = new PantosRegistryFacet();
        console2.log(
            "PantosRegistryFacet deployed; address=%s",
            address(registryFacet)
        );
        PantosTransferFacet transferFacet = new PantosTransferFacet();
        console2.log(
            "PantosTransferFacet deployed; address=%s",
            address(transferFacet)
        );

        DeployedFacets memory deployedFacets = DeployedFacets({
            dCut: dCutFacet,
            dLoupe: dLoupe,
            owner: ownerFacet,
            registry: registryFacet,
            transfer: transferFacet
        });

        // deploy initializer
        PantosHubInit pantosHubInit = new PantosHubInit();
        console2.log(
            "PantosHubInit deployed; address=%s",
            address(pantosHubInit)
        );

        // Prepare diamond cut and initializer data
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts(deployedFacets);
        bytes memory initializerData = prepareInitializerData(nextTransferId);

        // upgrade pantosHub diamond with facets using diamondCut
        IDiamondCut(address(pantosHubDiamond)).diamondCut(
            cut,
            address(pantosHubInit),
            initializerData
        );

        // wrap in IPantosHub ABI to support easier calls
        IPantosHub pantosHubProxy = IPantosHub(address(pantosHubDiamond));

        console2.log(
            "diamondCut PantosHubProxy; paused=%s; cut(s) count=%s; owner=%s",
            pantosHubProxy.paused(),
            cut.length,
            pantosHubProxy.owner()
        );
        return (pantosHubProxy, deployedFacets);
    }

    // Prepare cut struct for all the facets
    function prepareFacetCuts(
        DeployedFacets memory facets
    ) public pure returns (IDiamondCut.FacetCut[] memory) {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](4);

        // DiamondLoupeFacet
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(facets.dLoupe),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getDiamondLoupeSelectors()
        });

        // OwnershipFacet
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(facets.owner),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getOwnershipSelectors()
        });

        // PantosRegistryFacet
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(facets.registry),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getPantosRegistrySelectors()
        });

        // PantosTransferFacet
        cut[3] = IDiamondCut.FacetCut({
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
        uint256 feeFactorValidFrom = vm.unixTime() /
            1000 +
            Constants.FEE_FACTOR_VALID_FROM_OFFSET;

        PantosHubInit.Args memory args = PantosHubInit.Args({
            blockchainId: uint256(blockchain.blockchainId),
            blockchainName: blockchain.name,
            minimumTokenStake: Constants.MINIMUM_TOKEN_STAKE,
            minimumServiceNodeStake: Constants.MINIMUM_SERVICE_NODE_STAKE,
            unbondingPeriodServiceNodeStake: Constants
                .SERVICE_NODE_STAKE_UNBONDING_PERIOD,
            feeFactor: blockchain.feeFactor,
            feeFactorValidFrom: feeFactorValidFrom,
            minimumValidatorFeeUpdatePeriod: Constants
                .MINIMUM_VALIDATOR_FEE_UPDATE_PERIOD,
            nextTransferId: nextTransferId
        });
        bytes memory initializerData = abi.encodeCall(
            PantosHubInit.init,
            (args)
        );
        return initializerData;
    }

    function initializePantosHub(
        IPantosHub pantosHubProxy,
        PantosForwarder pantosForwarder,
        PantosToken pantosToken,
        address primaryValidatorNodeAddress
    ) public {
        if (!pantosHubProxy.paused()) {
            pantosHubProxy.pause();
            console2.log("PantosHub: paused=%s", pantosHubProxy.paused());
        }

        // Set the forwarder, PAN token, and primary validator node
        // addresses
        address currentForwarder = pantosHubProxy.getPantosForwarder();
        if (currentForwarder != address(pantosForwarder)) {
            pantosHubProxy.setPantosForwarder(address(pantosForwarder));
            console2.log(
                "PantosHub.setPantosForwarder(%s)",
                address(pantosForwarder)
            );
        } else {
            console2.log(
                "PantosHub: PantosForwarder already set, "
                "skipping setPantosForwarder(%s)",
                address(pantosForwarder)
            );
        }

        address currentPantosToken = pantosHubProxy.getPantosToken();
        if (currentPantosToken != address(pantosToken)) {
            pantosHubProxy.setPantosToken(address(pantosToken));
            console2.log("PantosHub.setPantosToken(%s)", address(pantosToken));
        } else {
            console2.log(
                "PantosHub: PantosToken already set, "
                "skipping setPantosToken(%s)",
                address(pantosToken)
            );
        }

        address currentPrimaryNode = pantosHubProxy.getPrimaryValidatorNode();
        if (currentPrimaryNode != primaryValidatorNodeAddress) {
            pantosHubProxy.setPrimaryValidatorNode(
                primaryValidatorNodeAddress
            );
            console2.log(
                "PantosHub.setPrimaryValidatorNode(%s)",
                primaryValidatorNodeAddress
            );
        } else {
            console2.log(
                "PantosHub: Primary Validator already set, "
                "skipping setPrimaryValidatorNode(%s)",
                primaryValidatorNodeAddress
            );
        }

        Blockchain memory blockchain = determineBlockchain();

        uint256 feeFactorValidFrom = vm.unixTime() /
            1000 +
            Constants.FEE_FACTOR_VALID_FROM_OFFSET;

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
                    memory blockchainRecord = pantosHubProxy
                        .getBlockchainRecord(
                            uint256(otherBlockchain.blockchainId)
                        );
                if (!blockchainRecord.active) {
                    pantosHubProxy.registerBlockchain(
                        uint256(otherBlockchain.blockchainId),
                        otherBlockchain.name,
                        otherBlockchain.feeFactor,
                        feeFactorValidFrom
                    );
                    console2.log(
                        "PantosHub.registerBlockchain(%s) on %s",
                        otherBlockchain.name,
                        blockchain.name
                    );
                } else if (
                    keccak256(abi.encodePacked(blockchainRecord.name)) !=
                    keccak256(abi.encodePacked(otherBlockchain.name))
                ) {
                    console2.log(
                        "PantosHub: blockchain names do not match. "
                        "Unregister and register again "
                        "Old name: %s New name: %s",
                        blockchainRecord.name,
                        otherBlockchain.name
                    );
                    pantosHubProxy.unregisterBlockchain(
                        uint256(otherBlockchain.blockchainId)
                    );
                    pantosHubProxy.registerBlockchain(
                        uint256(otherBlockchain.blockchainId),
                        otherBlockchain.name,
                        otherBlockchain.feeFactor,
                        feeFactorValidFrom
                    );
                    console2.log(
                        "PantosHub.unregisterBlockchain(%s), "
                        "PantosHub.registerBlockchain(%s), ",
                        uint256(otherBlockchain.blockchainId),
                        uint256(otherBlockchain.blockchainId)
                    );
                } else {
                    console2.log(
                        "PantosHub: Blockchain %s already registered "
                        "Skipping registerBlockchain(%s)",
                        otherBlockchain.name,
                        uint256(otherBlockchain.blockchainId)
                    );
                }
            }
        }
        // Unpause the hub contract after initialization
        pantosHubProxy.unpause();
        console2.log(
            "PantosHub initialized; paused=%s",
            pantosHubProxy.paused()
        );
    }

    function upgradePantosHub(address pantosHubProxyAddress) public {
        IPantosHub pantosHubProxy = IPantosHub(pantosHubProxyAddress);

        PantosRegistryFacet registryFacet = new PantosRegistryFacet();
        console2.log(
            "New PantosRegistryFacet deployed; address=%s",
            address(registryFacet)
        );
        PantosTransferFacet transferFacet = new PantosTransferFacet();
        console2.log(
            "New PantosTransferFacet deployed; address=%s",
            address(transferFacet)
        );

        // Prepare diamond cut
        IDiamondCut.FacetCut[] memory cut = preparePantosHubUpgradeFacetCuts(
            pantosHubProxyAddress,
            registryFacet,
            transferFacet
        );

        // Ensuring PantosHub is paused at the time of diamond cut
        if (!pantosHubProxy.paused()) {
            pantosHubProxy.pause();
            console2.log("PantosHub: paused=%s", pantosHubProxy.paused());
        }

        // upgrade pantosHub diamond with facets using diamondCut
        IDiamondCut(pantosHubProxyAddress).diamondCut(cut, address(0), "");

        console2.log(
            "diamondCut PantosHubProxy; paused=%s; cut(s) count=%s; owner=%s",
            pantosHubProxy.paused(),
            cut.length,
            pantosHubProxy.owner()
        );

        // this will do nothing if there is nothing new added to the storage slots
        initializePantosHub(
            pantosHubProxy,
            PantosForwarder(pantosHubProxy.getPantosForwarder()),
            PantosToken(pantosHubProxy.getPantosToken()),
            pantosHubProxy.getPrimaryValidatorNode()
        );
    }

    function getUpgradeFacetCut(
        address newFacetAddress,
        bytes4[] memory newSelectors,
        bytes4[] memory oldSelectors
    ) public pure returns (IDiamondCut.FacetCut[] memory) {
        bytes4 oldInterfaceId = _calculateInterfaceId(oldSelectors);
        bytes4 newInterfaceId = _calculateInterfaceId(newSelectors);

        if (oldInterfaceId == newInterfaceId) {
            console2.log(
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
            console2.log(
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
        console2.log(
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

        console2.log(
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
        bytes4[] memory selectors = new bytes4[](46);
        selectors[0] = IPantosRegistry.setPantosForwarder.selector;
        selectors[1] = IPantosRegistry.setPantosToken.selector;
        selectors[2] = IPantosRegistry.setPrimaryValidatorNode.selector;
        selectors[3] = IPantosRegistry.registerBlockchain.selector;
        selectors[4] = IPantosRegistry.unregisterBlockchain.selector;
        selectors[5] = IPantosRegistry.updateBlockchainName.selector;
        selectors[6] = IPantosRegistry.updateFeeFactor.selector;
        selectors[7] = IPantosRegistry.setMinimumTokenStake.selector;
        selectors[8] = IPantosRegistry
            .setUnbondingPeriodServiceNodeStake
            .selector;
        selectors[9] = IPantosRegistry.setMinimumServiceNodeStake.selector;
        selectors[10] = IPantosRegistry
            .setMinimumValidatorFeeUpdatePeriod
            .selector;
        selectors[11] = IPantosRegistry.registerToken.selector;
        selectors[12] = IPantosRegistry.unregisterToken.selector;
        selectors[13] = IPantosRegistry.increaseTokenStake.selector;
        selectors[14] = IPantosRegistry.decreaseTokenStake.selector;
        selectors[15] = IPantosRegistry.registerExternalToken.selector;
        selectors[16] = IPantosRegistry.unregisterExternalToken.selector;
        selectors[17] = IPantosRegistry.registerServiceNode.selector;
        selectors[18] = IPantosRegistry.unregisterServiceNode.selector;
        selectors[19] = IPantosRegistry.withdrawServiceNodeStake.selector;
        selectors[20] = IPantosRegistry
            .cancelServiceNodeUnregistration
            .selector;
        selectors[21] = IPantosRegistry.increaseServiceNodeStake.selector;
        selectors[22] = IPantosRegistry.decreaseServiceNodeStake.selector;
        selectors[23] = IPantosRegistry.updateServiceNodeUrl.selector;

        selectors[24] = IPantosRegistry.getPantosForwarder.selector;
        selectors[25] = IPantosRegistry.getPantosToken.selector;
        selectors[26] = IPantosRegistry.getPrimaryValidatorNode.selector;
        selectors[27] = IPantosRegistry.getNumberBlockchains.selector;
        selectors[28] = IPantosRegistry.getNumberActiveBlockchains.selector;
        selectors[29] = IPantosRegistry.getCurrentBlockchainId.selector;
        selectors[30] = IPantosRegistry.getBlockchainRecord.selector;
        selectors[31] = IPantosRegistry.getMinimumTokenStake.selector;
        selectors[32] = IPantosRegistry
            .isServiceNodeInTheUnbondingPeriod
            .selector;
        selectors[33] = IPantosRegistry.isValidValidatorNodeNonce.selector;
        selectors[34] = IPantosRegistry.getMinimumServiceNodeStake.selector;
        selectors[35] = IPantosRegistry
            .getUnbondingPeriodServiceNodeStake
            .selector;
        selectors[36] = IPantosRegistry.getTokens.selector;
        selectors[37] = IPantosRegistry.getTokenRecord.selector;
        selectors[38] = IPantosRegistry.getExternalTokenRecord.selector;
        selectors[39] = IPantosRegistry.getServiceNodes.selector;
        selectors[40] = IPantosRegistry.getServiceNodeRecord.selector;
        selectors[41] = IPantosRegistry.getValidatorFeeRecord.selector;
        selectors[42] = IPantosRegistry
            .getMinimumValidatorFeeUpdatePeriod
            .selector;

        selectors[43] = IPantosRegistry.pause.selector;
        selectors[44] = IPantosRegistry.unpause.selector;
        selectors[45] = IPantosRegistry.paused.selector;

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

    function getOwnershipSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = IERC173.owner.selector;
        selectors[1] = IERC173.transferOwnership.selector;
        return selectors;
    }
}
