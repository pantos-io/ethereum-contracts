// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@diamond/interfaces/IDiamondLoupe.sol";
import {IERC165} from "@diamond/interfaces/IERC165.sol";
import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";

import {PantosTypes} from "../src/interfaces/PantosTypes.sol";
import {IPantosHub} from "../src/interfaces/IPantosHub.sol";
import {IPantosTransfer} from "../src/interfaces/IPantosTransfer.sol";
import {IPantosRegistry} from "../src/interfaces/IPantosRegistry.sol";
import {PantosRegistryFacet} from "../src/facets/PantosRegistryFacet.sol";
import {PantosTransferFacet} from "../src/facets/PantosTransferFacet.sol";
import {PantosHubInit} from "../src/upgradeInitializers/PantosHubInit.sol";
import {PantosHubProxy} from "../src/PantosHubProxy.sol";
import {PantosBaseToken} from "../src/PantosBaseToken.sol";
import {DiamondCutFacet} from "../src/facets/DiamondCutFacet.sol";
import {AccessController} from "../src/access/AccessController.sol";

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
    PantosRegistryFacet public pantosRegistryFacet;
    PantosTransferFacet public pantosTransferFacet;
    PantosHubInit public pantosHubInit;

    function deployPantosHub(AccessController accessController) public {
        deployPantosHubProxyAndDiamondCutFacet(accessController);
        deployAllFacetsAndDiamondCut();
    }

    // deploy PantosHubProxy (diamond proxy) with diamondCut facet
    function deployPantosHubProxyAndDiamondCutFacet(
        AccessController accessController
    ) public {
        dCutFacet = new DiamondCutFacet();
        pantosHubDiamond = new PantosHubProxy(
            address(dCutFacet),
            address(accessController)
        );
    }

    function deployAllFacets() public {
        dLoupe = new DiamondLoupeFacet();
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
        vm.prank(DEPLOYER);
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
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);

        // DiamondLoupeFacet
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(dLoupe),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getDiamondLoupeSelectors()
            })
        );

        // PantosRegistryFacet
        cut[1] = (
            IDiamondCut.FacetCut({
                facetAddress: address(pantosRegistryFacet),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getPantosRegistrySelectors()
            })
        );

        // PantosTransferFacet
        cut[2] = (
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
            validatorFeeFactor: thisBlockchain.feeFactor,
            parameterUpdateDelay: PARAMETER_UPDATE_DELAY,
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
        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.registerBlockchain(
            uint256(otherBlockchain.blockchainId),
            otherBlockchain.name,
            otherBlockchain.feeFactor
        );
    }

    function initializePantosHub() public {
        if (!initialized) {
            _initializePantosHubValues();

            vm.prank(SUPER_CRITICAL_OPS);
            // Unpause the hub contract after initialization
            pantosHubProxy.unpause();
            initialized = true;
        }
    }

    function _initializePantosHubValues() public {
        mockPandasToken_getOwner(PANTOS_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);
        mockPandasToken_getPantosForwarder(
            PANTOS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );

        // Set the forwarder, PAN token, and primary validator addresses
        vm.startPrank(SUPER_CRITICAL_OPS);
        pantosHubProxy.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        pantosHubProxy.setPrimaryValidatorNode(validatorAddress);
        pantosHubProxy.setPantosToken(PANTOS_TOKEN_ADDRESS);
        vm.stopPrank();

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
        vm.prank(DEPLOYER);
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

    function mockPandasToken_getPantosForwarder(
        address tokenAddress,
        address pantosForwarderAddress
    ) public {
        vm.mockCall(
            tokenAddress,
            abi.encodeWithSelector(
                PantosBaseToken.getPantosForwarder.selector
            ),
            abi.encode(pantosForwarderAddress)
        );
    }

    function checkSupportedInterfaces() public {
        IERC165 ierc165 = IERC165(address(pantosHubDiamond));
        assertTrue(ierc165.supportsInterface(type(IERC165).interfaceId));
        assertTrue(ierc165.supportsInterface(type(IDiamondCut).interfaceId));
        assertTrue(ierc165.supportsInterface(type(IDiamondLoupe).interfaceId));
    }

    function checkStatePantosHub(
        bool paused,
        uint256 numberBlockchains,
        uint256 numberActiveBlockchains
    ) private {
        checkSupportedInterfaces();
        assertEq(pantosHubProxy.paused(), paused);
        assertEq(pantosHubProxy.getNumberBlockchains(), numberBlockchains);
        assertEq(
            pantosHubProxy.getNumberActiveBlockchains(),
            numberActiveBlockchains
        );

        PantosTypes.BlockchainRecord
            memory thisBlockchainRecord = pantosHubProxy.getBlockchainRecord(
                uint256(thisBlockchain.blockchainId)
            );
        assertEq(thisBlockchainRecord.name, thisBlockchain.name);
        assertTrue(thisBlockchainRecord.active);
        assertEq(
            pantosHubProxy.getCurrentBlockchainId(),
            uint256(thisBlockchain.blockchainId)
        );

        PantosTypes.UpdatableUint256
            memory thisBlockchainValidatorFeeFactor = pantosHubProxy
                .getValidatorFeeFactor(uint256(thisBlockchain.blockchainId));
        assertEq(
            thisBlockchainValidatorFeeFactor.currentValue,
            thisBlockchain.feeFactor
        );
        assertEq(thisBlockchainValidatorFeeFactor.pendingValue, 0);
        assertEq(thisBlockchainValidatorFeeFactor.updateTime, 0);

        PantosTypes.UpdatableUint256
            memory minimumServiceNodeDeposit = pantosHubProxy
                .getMinimumServiceNodeDeposit();
        assertEq(
            minimumServiceNodeDeposit.currentValue,
            MINIMUM_SERVICE_NODE_DEPOSIT
        );
        assertEq(minimumServiceNodeDeposit.pendingValue, 0);
        assertEq(minimumServiceNodeDeposit.updateTime, 0);

        PantosTypes.UpdatableUint256
            memory parameterUpdateDelay = pantosHubProxy
                .getParameterUpdateDelay();
        assertEq(parameterUpdateDelay.currentValue, PARAMETER_UPDATE_DELAY);
        assertEq(parameterUpdateDelay.pendingValue, 0);
        assertEq(parameterUpdateDelay.updateTime, 0);

        PantosTypes.UpdatableUint256
            memory unbondingPeriodServiceNodeDeposit = pantosHubProxy
                .getUnbondingPeriodServiceNodeDeposit();
        assertEq(
            unbondingPeriodServiceNodeDeposit.currentValue,
            SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD
        );
        assertEq(unbondingPeriodServiceNodeDeposit.pendingValue, 0);
        assertEq(unbondingPeriodServiceNodeDeposit.updateTime, 0);

        assertEq(pantosHubProxy.getNextTransferId(), 0);
    }

    // checks pre InitPantosHub state
    function checkStatePantosHubAfterDeployment() public {
        checkStatePantosHub(true, 1, 1);
    }

    // checks state after InitPantosHub
    function checkStatePantosHubAfterInit() public {
        checkStatePantosHub(false, 2, 2);

        assertEq(pantosHubProxy.getPantosToken(), PANTOS_TOKEN_ADDRESS);
        assertEq(
            pantosHubProxy.getPantosForwarder(),
            PANTOS_FORWARDER_ADDRESS
        );
        assertEq(pantosHubProxy.getPrimaryValidatorNode(), validatorAddress);

        PantosTypes.BlockchainRecord
            memory otherBlockchainRecord = pantosHubProxy.getBlockchainRecord(
                uint256(otherBlockchain.blockchainId)
            );
        assertEq(otherBlockchainRecord.name, otherBlockchain.name);
        assertTrue(otherBlockchainRecord.active);

        PantosTypes.UpdatableUint256
            memory otherBlockchainValidatorFeeFactor = pantosHubProxy
                .getValidatorFeeFactor(uint256(otherBlockchain.blockchainId));
        assertEq(
            otherBlockchainValidatorFeeFactor.currentValue,
            otherBlockchain.feeFactor
        );
        assertEq(otherBlockchainValidatorFeeFactor.pendingValue, 0);
        assertEq(otherBlockchainValidatorFeeFactor.updateTime, 0);
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
        returns (PantosTypes.UpdatableUint256 memory)
    {
        return loadPantosHubUpdatableUint256(7);
    }

    function loadPantosHubTokens() internal view returns (address[] memory) {
        bytes32 slotValue = loadPantosHubSlotValue(10);
        uint256 arrayLength = uint256(slotValue);
        address[] memory tokenAddresses = new address[](arrayLength);
        uint256 startSlot = uint256(keccak256(abi.encodePacked(uint256(10))));
        for (uint256 i = 0; i < arrayLength; i++) {
            slotValue = loadPantosHubSlotValue(startSlot + i);
            tokenAddresses[i] = toAddress(slotValue);
        }
        return tokenAddresses;
    }

    function loadPantosHubTokenIndex(
        address tokenAddress
    ) internal view returns (uint256) {
        uint256 slot = uint256(keccak256(abi.encode(tokenAddress, 11)));
        bytes32 slotValue = loadPantosHubSlotValue(slot);
        return uint256(slotValue);
    }

    function loadPantosHubTokenRecord(
        address tokenAddress
    ) internal view returns (PantosTypes.TokenRecord memory) {
        uint256 startSlot = uint256(keccak256(abi.encode(tokenAddress, 12)));
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
                    keccak256(abi.encode(tokenAddress, 13))
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
        bytes32 slotValue = loadPantosHubSlotValue(14);
        uint256 arrayLength = uint256(slotValue);
        address[] memory serviceNodeAddresses = new address[](arrayLength);
        uint256 startSlot = uint256(keccak256(abi.encodePacked(uint256(14))));
        for (uint256 i = 0; i < arrayLength; i++) {
            slotValue = loadPantosHubSlotValue(startSlot + i);
            serviceNodeAddresses[i] = toAddress(slotValue);
        }
        return serviceNodeAddresses;
    }

    function loadPantosHubServiceNodeIndex(
        address serviceNodeAddress
    ) internal view returns (uint256) {
        uint256 slot = uint256(keccak256(abi.encode(serviceNodeAddress, 15)));
        bytes32 slotValue = loadPantosHubSlotValue(slot);
        return uint256(slotValue);
    }

    function loadPantosHubServiceNodeRecord(
        address serviceNodeAddress
    ) internal view returns (PantosTypes.ServiceNodeRecord memory) {
        uint256 startSlot = uint256(
            keccak256(abi.encode(serviceNodeAddress, 16))
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
        bytes32 slotValue = loadPantosHubSlotValue(17);
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
                    keccak256(abi.encode(blockchainId, 18))
                )
            )
        );
        bytes32 slotValue = loadPantosHubSlotValue(slot);
        return toBool(slotValue);
    }

    function loadPantosHubValidatorFeeFactor(
        uint256 blockchainId
    ) internal view returns (PantosTypes.UpdatableUint256 memory) {
        uint256 startSlot = uint256(keccak256(abi.encode(blockchainId, 19)));
        return loadPantosHubUpdatableUint256(startSlot);
    }

    function loadPantosHubParameterUpdateDelay()
        internal
        view
        returns (PantosTypes.UpdatableUint256 memory)
    {
        return loadPantosHubUpdatableUint256(20);
    }

    function loadPantosHubUnbondingPeriodServiceNodeDeposit()
        internal
        view
        returns (PantosTypes.UpdatableUint256 memory)
    {
        return loadPantosHubUpdatableUint256(23);
    }

    function loadPantosHubIsServiceNodeUrlUsed(
        bytes32 serviceNodeUrlHash
    ) internal view returns (bool) {
        uint256 slot = uint256(keccak256(abi.encode(serviceNodeUrlHash, 26)));
        bytes32 slotValue = loadPantosHubSlotValue(slot);
        return toBool(slotValue);
    }

    function loadPantosHubSlotValue(
        uint256 slot
    ) private view returns (bytes32) {
        return vm.load(address(pantosHubProxy), bytes32(slot));
    }

    function loadPantosHubUpdatableUint256(
        uint256 startSlot
    ) private view returns (PantosTypes.UpdatableUint256 memory) {
        bytes32 slotValue = loadPantosHubSlotValue(startSlot);
        uint256 currentValue = uint256(slotValue);
        slotValue = loadPantosHubSlotValue(startSlot + 1);
        uint256 pendingValue = uint256(slotValue);
        slotValue = loadPantosHubSlotValue(startSlot + 2);
        uint256 updateTime = uint256(slotValue);
        return
            PantosTypes.UpdatableUint256(
                currentValue,
                pendingValue,
                updateTime
            );
    }
}
