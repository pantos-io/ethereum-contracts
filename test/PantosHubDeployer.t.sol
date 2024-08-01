// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@diamond/interfaces/IDiamondLoupe.sol";
import {IERC165} from "@diamond/interfaces/IERC165.sol";
import {IERC173} from "@diamond/interfaces/IERC173.sol";
import {DiamondCutFacet} from "@diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "@diamond/facets/OwnershipFacet.sol";

import {PantosTypes} from "../src/interfaces/PantosTypes.sol";
import {IPantosHub} from "../src/interfaces/IPantosHub.sol";
import {IPantosTransfer} from "../src/interfaces/IPantosTransfer.sol";
import {IPantosRegistry} from "../src/interfaces/IPantosRegistry.sol";
import {PantosRegistryFacet} from "../src/facets/PantosRegistryFacet.sol";
import {PantosTransferFacet} from "../src/facets/PantosTransferFacet.sol";
import {PantosHubInit} from "../src/upgradeInitializers/PantosHubInit.sol";
import {PantosHubProxy} from "../src/PantosHubProxy.sol";
import {PantosBaseToken} from "../src/PantosBaseToken.sol";

import {PantosBaseTest} from "./PantosBaseTest.t.sol";

abstract contract PantosHubDeployer is PantosBaseTest {
    address constant PANTOS_FORWARDER_ADDRESS =
        address(uint160(uint256(keccak256("PantosForwarderAddress"))));
    address constant PANTOS_TOKEN_ADDRESS =
        address(uint160(uint256(keccak256("PantosTokenAddress"))));
    address constant SERVICE_NODE_WITHDRAWAL_ADDRESS =
        address(uint160(uint256(keccak256("ServiceNodeWithdrawalAddress"))));
    address constant TRANSFER_SENDER =
        address(uint160(uint256(keccak256("TransferSender"))));

    bool initialized = false;
    PantosHubProxy pantosHubDiamond;
    IPantosHub public pantosHubProxy;
    DiamondCutFacet public dCutFacet;
    DiamondLoupeFacet public dLoupe;
    OwnershipFacet public ownerFacet;
    PantosRegistryFacet public pantosRegistryFacet;
    PantosTransferFacet public pantosTransferFacet;
    PantosHubInit public pantosHubInit;

    function deployPantosHub() public {
        deployPantosHubProxyAndDiamondCutFacet();
        deployAllFacetsAndDiamondCut();
    }

    // deploy PantosHubProxy (diamond proxy) with diamondCut facet
    function deployPantosHubProxyAndDiamondCutFacet() public {
        dCutFacet = new DiamondCutFacet();
        pantosHubDiamond = new PantosHubProxy(
            address(this),
            address(dCutFacet)
        );
    }

    function deployAllFacets() public {
        dLoupe = new DiamondLoupeFacet();
        ownerFacet = new OwnershipFacet();
        pantosRegistryFacet = new PantosRegistryFacet();
        pantosTransferFacet = new PantosTransferFacet();
    }

    function deployAllFacetsAndDiamondCut() public {
        deployAllFacets();

        pantosHubInit = new PantosHubInit();

        // Prepare diamond cut and initializer data
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts();
        bytes memory initializerData = prepareInitializerData(
            getInitializerArgs()
        );

        // upgrade pantosHub diamond with facets using diamondCut
        IDiamondCut(address(pantosHubDiamond)).diamondCut(
            cut,
            address(pantosHubInit),
            initializerData
        );

        // wrap in IPantosHub ABI to support easier calls
        pantosHubProxy = IPantosHub(address(pantosHubDiamond));
    }

    // Prepare cut struct for all the facets
    function prepareFacetCuts()
        public
        view
        returns (IDiamondCut.FacetCut[] memory)
    {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](4);

        // DiamondLoupeFacet
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(dLoupe),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getDiamondLoupeSelectors()
            })
        );

        // OwnershipFacet
        cut[1] = (
            IDiamondCut.FacetCut({
                facetAddress: address(ownerFacet),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getOwnershipSelectors()
            })
        );

        // PantosRegistryFacet
        cut[2] = (
            IDiamondCut.FacetCut({
                facetAddress: address(pantosRegistryFacet),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getPantosRegistrySelectors()
            })
        );

        // PantosTransferFacet
        cut[3] = (
            IDiamondCut.FacetCut({
                facetAddress: address(pantosTransferFacet),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getPantosTransferSelectors()
            })
        );
        return cut;
    }

    function getInitializerArgs()
        public
        view
        returns (PantosHubInit.Args memory)
    {
        PantosHubInit.Args memory args = PantosHubInit.Args({
            blockchainId: uint256(thisBlockchain.blockchainId),
            blockchainName: thisBlockchain.name,
            minimumServiceNodeDeposit: MINIMUM_SERVICE_NODE_DEPOSIT,
            unbondingPeriodServiceNodeDeposit: SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD,
            feeFactor: thisBlockchain.feeFactor,
            feeFactorValidFrom: FEE_FACTOR_VALID_FROM,
            minimumValidatorFeeUpdatePeriod: MINIMUM_VALIDATOR_FEE_UPDATE_PERIOD,
            nextTransferId: 0
        });
        return args;
    }

    // initializing PantosHub storage using one-off helper contract
    function prepareInitializerData(
        PantosHubInit.Args memory args
    ) public pure returns (bytes memory) {
        bytes memory initializerData = abi.encodeCall(
            PantosHubInit.init,
            (args)
        );
        return initializerData;
    }

    function registerOtherBlockchainAtPantosHub() public {
        pantosHubProxy.registerBlockchain(
            uint256(otherBlockchain.blockchainId),
            otherBlockchain.name,
            otherBlockchain.feeFactor,
            FEE_FACTOR_VALID_FROM
        );
    }

    function initializePantosHub() public {
        if (!initialized) {
            _initializePantosHubValues();

            // Unpause the hub contract after initialization
            pantosHubProxy.unpause();
            initialized = true;
        }
    }

    function _initializePantosHubValues() public {
        mockPandasToken_getOwner(PANTOS_TOKEN_ADDRESS, deployer());

        // Set the forwarder, PAN token, and primary validator addresses
        pantosHubProxy.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        pantosHubProxy.setPantosToken(PANTOS_TOKEN_ADDRESS);
        pantosHubProxy.setPrimaryValidatorNode(validatorAddress);

        registerOtherBlockchainAtPantosHub();
    }

    function reDeployRegistryAndTransferFacetsAndDiamondCut() public {
        pantosRegistryFacet = new PantosRegistryFacet();
        pantosTransferFacet = new PantosTransferFacet();

        // Prepare diamond cut
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](2);
        // PantosRegistryFacet
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(pantosRegistryFacet),
                action: IDiamondCut.FacetCutAction.Replace,
                functionSelectors: getPantosRegistrySelectors()
            })
        );

        // PantosTransferFacet
        cut[1] = (
            IDiamondCut.FacetCut({
                facetAddress: address(pantosTransferFacet),
                action: IDiamondCut.FacetCutAction.Replace,
                functionSelectors: getPantosTransferSelectors()
            })
        );

        // upgrade pantosHub diamond with facets using diamondCut
        IDiamondCut(address(pantosHubDiamond)).diamondCut(cut, address(0), "");

        // wrap in IPantosHub ABI to support easier calls
        pantosHubProxy = IPantosHub(address(pantosHubDiamond));
    }

    function mockPandasToken_getOwner(
        address tokenAddress,
        address owner
    ) public {
        vm.mockCall(
            tokenAddress,
            abi.encodeWithSelector(PantosBaseToken.getOwner.selector),
            abi.encode(owner)
        );
    }

    function checkSupportedInterfaces() public {
        IERC165 ierc165 = IERC165(address(pantosHubDiamond));
        assertTrue(ierc165.supportsInterface(type(IERC165).interfaceId));
        assertTrue(ierc165.supportsInterface(type(IDiamondCut).interfaceId));
        assertTrue(ierc165.supportsInterface(type(IDiamondLoupe).interfaceId));
        assertTrue(ierc165.supportsInterface(type(IERC173).interfaceId));
    }

    // checks pre InitPantosHub state
    function checkStatePantosHubAfterDeployment() public {
        checkSupportedInterfaces();
        assertEq(pantosHubProxy.owner(), deployer());
        assertTrue(pantosHubProxy.paused());
        assertEq(pantosHubProxy.getNumberBlockchains(), 1);
        assertEq(pantosHubProxy.getNumberActiveBlockchains(), 1);
        assertEq(
            pantosHubProxy.getMinimumValidatorFeeUpdatePeriod(),
            MINIMUM_VALIDATOR_FEE_UPDATE_PERIOD
        );

        PantosTypes.BlockchainRecord
            memory thisBlockchainRecord = pantosHubProxy.getBlockchainRecord(
                uint256(thisBlockchain.blockchainId)
            );
        PantosTypes.ValidatorFeeRecord
            memory thisBlockchainValidatorFeeRecord = pantosHubProxy
                .getValidatorFeeRecord(uint256(thisBlockchain.blockchainId));

        assertEq(thisBlockchainRecord.name, thisBlockchain.name);
        assertEq(thisBlockchainRecord.active, true);
        assertEq(
            pantosHubProxy.getCurrentBlockchainId(),
            uint256(thisBlockchain.blockchainId)
        );
        assertEq(
            thisBlockchainValidatorFeeRecord.newFactor,
            thisBlockchain.feeFactor
        );
        assertEq(thisBlockchainValidatorFeeRecord.oldFactor, 0);
        assertEq(
            thisBlockchainValidatorFeeRecord.validFrom,
            FEE_FACTOR_VALID_FROM
        );
        assertEq(
            pantosHubProxy.getMinimumServiceNodeDeposit(),
            MINIMUM_SERVICE_NODE_DEPOSIT
        );
        assertEq(
            pantosHubProxy.getUnbondingPeriodServiceNodeDeposit(),
            SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD
        );
        assertEq(pantosHubProxy.getNextTransferId(), 0);
    }

    // checks state after InitPantosHub
    function checkStatePantosHubAfterInit() public {
        checkSupportedInterfaces();
        assertEq(pantosHubProxy.owner(), deployer());
        assertFalse(pantosHubProxy.paused());
        assertEq(pantosHubProxy.getPantosToken(), PANTOS_TOKEN_ADDRESS);
        assertEq(
            pantosHubProxy.getPantosForwarder(),
            PANTOS_FORWARDER_ADDRESS
        );
        assertEq(pantosHubProxy.getPrimaryValidatorNode(), validatorAddress);
        assertEq(pantosHubProxy.getNumberBlockchains(), 2);
        assertEq(pantosHubProxy.getNumberActiveBlockchains(), 2);
        assertEq(
            pantosHubProxy.getMinimumValidatorFeeUpdatePeriod(),
            MINIMUM_VALIDATOR_FEE_UPDATE_PERIOD
        );
        PantosTypes.BlockchainRecord
            memory thisBlockchainRecord = pantosHubProxy.getBlockchainRecord(
                uint256(thisBlockchain.blockchainId)
            );
        PantosTypes.ValidatorFeeRecord
            memory thisBlockchainValidatorFeeRecord = pantosHubProxy
                .getValidatorFeeRecord(uint256(thisBlockchain.blockchainId));
        assertEq(thisBlockchainRecord.name, thisBlockchain.name);
        assertEq(thisBlockchainRecord.active, true);
        assertEq(
            pantosHubProxy.getCurrentBlockchainId(),
            uint256(thisBlockchain.blockchainId)
        );
        assertEq(
            thisBlockchainValidatorFeeRecord.newFactor,
            thisBlockchain.feeFactor
        );
        assertEq(thisBlockchainValidatorFeeRecord.oldFactor, 0);
        assertEq(
            thisBlockchainValidatorFeeRecord.validFrom,
            FEE_FACTOR_VALID_FROM
        );
        PantosTypes.BlockchainRecord
            memory otherBlockchainRecord = pantosHubProxy.getBlockchainRecord(
                uint256(otherBlockchain.blockchainId)
            );

        PantosTypes.ValidatorFeeRecord
            memory otherBlockchainValidatorFeeRecord = pantosHubProxy
                .getValidatorFeeRecord(uint256(otherBlockchain.blockchainId));
        assertEq(otherBlockchainRecord.name, otherBlockchain.name);
        assertEq(otherBlockchainRecord.active, true);
        assertEq(
            otherBlockchainValidatorFeeRecord.newFactor,
            otherBlockchain.feeFactor
        );
        assertEq(otherBlockchainValidatorFeeRecord.oldFactor, 0);
        assertEq(
            otherBlockchainValidatorFeeRecord.validFrom,
            FEE_FACTOR_VALID_FROM
        );

        assertEq(
            pantosHubProxy.getMinimumServiceNodeDeposit(),
            MINIMUM_SERVICE_NODE_DEPOSIT
        );
        assertEq(
            pantosHubProxy.getUnbondingPeriodServiceNodeDeposit(),
            SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD
        );
        assertEq(pantosHubProxy.getNextTransferId(), 0);
    }

    function getPantosRegistrySelectors()
        public
        pure
        returns (bytes4[] memory)
    {
        bytes4[] memory selectors = new bytes4[](42);
        selectors[0] = IPantosRegistry.setPantosForwarder.selector;
        selectors[1] = IPantosRegistry.setPantosToken.selector;
        selectors[2] = IPantosRegistry.setPrimaryValidatorNode.selector;
        selectors[3] = IPantosRegistry.registerBlockchain.selector;
        selectors[4] = IPantosRegistry.unregisterBlockchain.selector;
        selectors[5] = IPantosRegistry.updateBlockchainName.selector;
        selectors[6] = IPantosRegistry.updateFeeFactor.selector;
        selectors[7] = IPantosRegistry
            .setUnbondingPeriodServiceNodeDeposit
            .selector;
        selectors[8] = IPantosRegistry.setMinimumServiceNodeDeposit.selector;
        selectors[9] = IPantosRegistry
            .setMinimumValidatorFeeUpdatePeriod
            .selector;
        selectors[10] = IPantosRegistry.registerToken.selector;
        selectors[11] = IPantosRegistry.unregisterToken.selector;
        selectors[12] = IPantosRegistry.registerExternalToken.selector;
        selectors[13] = IPantosRegistry.unregisterExternalToken.selector;
        selectors[14] = IPantosRegistry.registerServiceNode.selector;
        selectors[15] = IPantosRegistry.unregisterServiceNode.selector;
        selectors[16] = IPantosRegistry.withdrawServiceNodeDeposit.selector;
        selectors[17] = IPantosRegistry
            .cancelServiceNodeUnregistration
            .selector;
        selectors[18] = IPantosRegistry.increaseServiceNodeDeposit.selector;
        selectors[19] = IPantosRegistry.decreaseServiceNodeDeposit.selector;
        selectors[20] = IPantosRegistry.updateServiceNodeUrl.selector;

        selectors[21] = IPantosRegistry.getPantosForwarder.selector;
        selectors[22] = IPantosRegistry.getPantosToken.selector;
        selectors[23] = IPantosRegistry.getPrimaryValidatorNode.selector;
        selectors[24] = IPantosRegistry.getNumberBlockchains.selector;
        selectors[25] = IPantosRegistry.getNumberActiveBlockchains.selector;
        selectors[26] = IPantosRegistry.getCurrentBlockchainId.selector;
        selectors[27] = IPantosRegistry.getBlockchainRecord.selector;
        selectors[28] = IPantosRegistry
            .isServiceNodeInTheUnbondingPeriod
            .selector;
        selectors[29] = IPantosRegistry.isValidValidatorNodeNonce.selector;
        selectors[30] = IPantosRegistry.getMinimumServiceNodeDeposit.selector;
        selectors[31] = IPantosRegistry
            .getUnbondingPeriodServiceNodeDeposit
            .selector;
        selectors[32] = IPantosRegistry.getTokens.selector;
        selectors[33] = IPantosRegistry.getTokenRecord.selector;
        selectors[34] = IPantosRegistry.getExternalTokenRecord.selector;
        selectors[35] = IPantosRegistry.getServiceNodes.selector;
        selectors[36] = IPantosRegistry.getServiceNodeRecord.selector;
        selectors[37] = IPantosRegistry.getValidatorFeeRecord.selector;
        selectors[38] = IPantosRegistry
            .getMinimumValidatorFeeUpdatePeriod
            .selector;

        selectors[39] = IPantosRegistry.pause.selector;
        selectors[40] = IPantosRegistry.unpause.selector;
        selectors[41] = IPantosRegistry.paused.selector;
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

    function loadPantosHubInitialized() internal view returns (uint64) {
        bytes32 slotValue = loadPantosHubSlotValue(0);
        return uint64(uint256(slotValue));
    }

    function loadPantosHubPaused() internal view returns (bool) {
        bytes32 slotValue = loadPantosHubSlotValue(0);
        return toBool(slotValue >> 64);
    }

    function loadPantosHubPantosForwarder() internal view returns (address) {
        bytes32 slotValue = loadPantosHubSlotValue(0);
        return toAddress(slotValue >> 72);
    }

    function loadPantosHubPantosToken() internal view returns (address) {
        bytes32 slotValue = loadPantosHubSlotValue(1);
        return toAddress(slotValue);
    }

    function loadPantosHubPrimaryValidatorNodeAddress()
        internal
        view
        returns (address)
    {
        bytes32 slotValue = loadPantosHubSlotValue(2);
        return toAddress(slotValue);
    }

    function loadPantosHubNumberBlockchains() internal view returns (uint256) {
        bytes32 slotValue = loadPantosHubSlotValue(3);
        return uint256(slotValue);
    }

    function loadPantosHubNumberActiveBlockchains()
        internal
        view
        returns (uint256)
    {
        bytes32 slotValue = loadPantosHubSlotValue(4);
        return uint256(slotValue);
    }

    function loadPantosHubCurrentBlockchainId()
        internal
        view
        returns (uint256)
    {
        bytes32 slotValue = loadPantosHubSlotValue(5);
        return uint256(slotValue);
    }

    function loadPantosHubBlockchainRecord(
        uint256 blockchainId
    ) internal view returns (PantosTypes.BlockchainRecord memory) {
        uint256 startSlot = uint256(keccak256(abi.encode(blockchainId, 6)));
        bytes32 slotValue = loadPantosHubSlotValue(startSlot);
        bool active = toBool(slotValue);
        slotValue = loadPantosHubSlotValue(startSlot + 1);
        string memory name = string(abi.encodePacked(slotValue));
        return PantosTypes.BlockchainRecord(active, name);
    }

    function loadPantosHubMinimumServiceNodeDeposit()
        internal
        view
        returns (uint256)
    {
        bytes32 slotValue = loadPantosHubSlotValue(7);
        return uint256(slotValue);
    }

    function loadPantosHubTokens() internal view returns (address[] memory) {
        bytes32 slotValue = loadPantosHubSlotValue(8);
        uint256 arrayLength = uint256(slotValue);
        address[] memory tokenAddresses = new address[](arrayLength);
        uint256 startSlot = uint256(keccak256(abi.encodePacked(uint256(8))));
        for (uint256 i = 0; i < arrayLength; i++) {
            slotValue = loadPantosHubSlotValue(startSlot + i);
            tokenAddresses[i] = toAddress(slotValue);
        }
        return tokenAddresses;
    }

    function loadPantosHubTokenIndex(
        address tokenAddress
    ) internal view returns (uint256) {
        uint256 slot = uint256(keccak256(abi.encode(tokenAddress, 9)));
        bytes32 slotValue = loadPantosHubSlotValue(slot);
        return uint256(slotValue);
    }

    function loadPantosHubTokenRecord(
        address tokenAddress
    ) internal view returns (PantosTypes.TokenRecord memory) {
        uint256 startSlot = uint256(keccak256(abi.encode(tokenAddress, 10)));
        bytes32 slotValue = loadPantosHubSlotValue(startSlot);
        bool active = toBool(slotValue);
        return PantosTypes.TokenRecord(active);
    }

    function loadPantosHubExternalTokenRecord(
        address tokenAddress,
        uint256 blockchainId
    ) internal view returns (PantosTypes.ExternalTokenRecord memory) {
        uint256 startSlot = uint256(
            keccak256(
                abi.encode(
                    blockchainId,
                    keccak256(abi.encode(tokenAddress, 11))
                )
            )
        );
        bytes32 slotValue = loadPantosHubSlotValue(startSlot);
        bool active = toBool(slotValue);
        slotValue = loadPantosHubSlotValue(startSlot + 1);
        string memory externalTokenAddress = string(
            abi.encodePacked(slotValue)
        );
        return PantosTypes.ExternalTokenRecord(active, externalTokenAddress);
    }

    function loadPantosHubServiceNodes()
        internal
        view
        returns (address[] memory)
    {
        bytes32 slotValue = loadPantosHubSlotValue(12);
        uint256 arrayLength = uint256(slotValue);
        address[] memory serviceNodeAddresses = new address[](arrayLength);
        uint256 startSlot = uint256(keccak256(abi.encodePacked(uint256(12))));
        for (uint256 i = 0; i < arrayLength; i++) {
            slotValue = loadPantosHubSlotValue(startSlot + i);
            serviceNodeAddresses[i] = toAddress(slotValue);
        }
        return serviceNodeAddresses;
    }

    function loadPantosHubServiceNodeIndex(
        address serviceNodeAddress
    ) internal view returns (uint256) {
        uint256 slot = uint256(keccak256(abi.encode(serviceNodeAddress, 13)));
        bytes32 slotValue = loadPantosHubSlotValue(slot);
        return uint256(slotValue);
    }

    function loadPantosHubServiceNodeRecord(
        address serviceNodeAddress
    ) internal view returns (PantosTypes.ServiceNodeRecord memory) {
        uint256 startSlot = uint256(
            keccak256(abi.encode(serviceNodeAddress, 14))
        );
        bytes32 slotValue = loadPantosHubSlotValue(startSlot);
        bool active = toBool(slotValue);
        slotValue = loadPantosHubSlotValue(startSlot + 1);
        string memory url = string(abi.encodePacked(slotValue));
        slotValue = loadPantosHubSlotValue(startSlot + 2);
        uint256 deposit = uint256(slotValue);
        slotValue = loadPantosHubSlotValue(startSlot + 3);
        address withdrawalAddress = toAddress(slotValue);
        slotValue = loadPantosHubSlotValue(startSlot + 4);
        uint256 unregisterTime = uint256(slotValue);
        return
            PantosTypes.ServiceNodeRecord(
                active,
                url,
                deposit,
                withdrawalAddress,
                unregisterTime
            );
    }

    function loadPantosHubNextTransferId() internal view returns (uint256) {
        bytes32 slotValue = loadPantosHubSlotValue(15);
        return uint256(slotValue);
    }

    function loadPantosHubUsedSourceTransferId(
        uint256 blockchainId,
        uint256 sourceTransferId
    ) internal view returns (bool) {
        uint256 slot = uint256(
            keccak256(
                abi.encode(
                    sourceTransferId,
                    keccak256(abi.encode(blockchainId, 16))
                )
            )
        );
        bytes32 slotValue = loadPantosHubSlotValue(slot);
        return toBool(slotValue);
    }

    function loadPantosHubValidatorFeeRecord(
        uint256 blockchainId
    ) internal view returns (PantosTypes.ValidatorFeeRecord memory) {
        uint256 startSlot = uint256(keccak256(abi.encode(blockchainId, 17)));
        bytes32 slotValue = loadPantosHubSlotValue(startSlot);
        uint256 oldFactor = uint256(slotValue);
        slotValue = loadPantosHubSlotValue(startSlot + 1);
        uint256 newFactor = uint256(slotValue);
        slotValue = loadPantosHubSlotValue(startSlot + 2);
        uint256 validFrom = uint256(slotValue);
        return PantosTypes.ValidatorFeeRecord(oldFactor, newFactor, validFrom);
    }

    function loadPantosHubMinimumValidatorFeeUpdatePeriod()
        internal
        view
        returns (uint256)
    {
        bytes32 slotValue = loadPantosHubSlotValue(18);
        return uint256(slotValue);
    }

    function loadPantosHubUnbondingPeriodServiceNodeDeposit()
        internal
        view
        returns (uint256)
    {
        bytes32 slotValue = loadPantosHubSlotValue(19);
        return uint256(slotValue);
    }

    function loadPantosHubIsServiceNodeUrlUsed(
        bytes32 serviceNodeUrlHash
    ) internal view returns (bool) {
        uint256 slot = uint256(keccak256(abi.encode(serviceNodeUrlHash, 20)));
        bytes32 slotValue = loadPantosHubSlotValue(slot);
        return toBool(slotValue);
    }

    function loadPantosHubSlotValue(
        uint256 slot
    ) private view returns (bytes32) {
        return vm.load(address(pantosHubProxy), bytes32(slot));
    }
}
