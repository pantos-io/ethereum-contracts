// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@diamond/interfaces/IDiamondLoupe.sol";
import {IERC165} from "@diamond/interfaces/IERC165.sol";
import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";
import {console2} from "forge-std/console2.sol";

import {IPantosRegistry} from "../src/interfaces/IPantosRegistry.sol";
import {IPantosTransfer} from "../src/interfaces/IPantosTransfer.sol";
import {PantosRegistryFacet} from "../src/facets/PantosRegistryFacet.sol";
import {PantosTransferFacet} from "../src/facets/PantosTransferFacet.sol";
import {PantosHubInit} from "../src/upgradeInitializers/PantosHubInit.sol";
import {DiamondCutFacet} from "../src/facets/DiamondCutFacet.sol";
import {AccessController} from "../src/access/AccessController.sol";

import {PantosHubDeployer} from "./PantosHubDeployer.t.sol";
import {DummyFacet} from "./helpers/DummyFacet.sol";
import {IPantosTransferV2} from "./helpers/IPantosTransferV2.sol";
import {PantosTransferV2Facet} from "./helpers/PantosTransferV2Facet.sol";
import {PantosHubReinit} from "./helpers/PantosHubReinit.sol";

contract PantosHubProxyTest is PantosHubDeployer {
    event Response(bool success, bytes data);

    DummyFacet dummyFacet;
    AccessController accessController;

    function setUp() public {
        accessController = deployAccessController();
        deployPantosHubProxyAndDiamondCutFacet(accessController);
    }

    function test_fallback_sendEthToPantosHubUsingCall() external {
        (bool success, bytes memory result) = address(pantosHubDiamond).call{
            value: 100
        }("");
        assertFalse(success);
        assertEq(getRevertMsg(result), "PantosHub: Function does not exist");
    }

    function test_fallback_sendEthToPantosHubUsingTransfer() external {
        vm.expectRevert();
        payable(address(pantosHubDiamond)).transfer(10000);
    }

    function test_fallback_sendEthToPantosHubUsingSend() external {
        bool success = payable(address(pantosHubDiamond)).send(100);
        assertFalse(success);
    }

    function test_fallback_setPantosForwarderWithEth() external {
        deployAllFacetsAndDiamondCut();
        initializePantosHub();
        (bool success, bytes memory result) = address(pantosHubDiamond).call{
            value: 100
        }(
            abi.encodeWithSignature(
                "setPantosForwarder(address)",
                PANTOS_FORWARDER_ADDRESS
            )
        );
        assertFalse(success);
        assertEq(getRevertMsg(result), "");
    }

    function test_fallback_callNonExistingMethod() external {
        (bool success, bytes memory result) = address(pantosHubDiamond).call(
            abi.encodeWithSignature(
                "NonExistingMethod(address)",
                PANTOS_FORWARDER_ADDRESS
            )
        );
        assertFalse(success);
        assertEq(getRevertMsg(result), "PantosHub: Function does not exist");
    }

    function test_fallback_callNonExistingMethodAfterInitPantosHub() external {
        deployAllFacetsAndDiamondCut();
        initializePantosHub();
        checkStatePantosHubAfterInit();

        (bool success, bytes memory result) = address(pantosHubDiamond).call(
            abi.encodeWithSignature(
                "NonExistingMethod(address)",
                PANTOS_FORWARDER_ADDRESS
            )
        );
        assertFalse(success);
        assertEq(getRevertMsg(result), "PantosHub: Function does not exist");
    }

    function test_fallback_setPantosForwarderWithWrongParamType() external {
        deployAllFacetsAndDiamondCut();
        initializePantosHub();
        (bool success, bytes memory result) = address(pantosHubDiamond).call(
            abi.encodeWithSignature("setPantosForwarder(uint256)", 999)
        );
        assertFalse(success);
        assertEq(getRevertMsg(result), "PantosHub: Function does not exist");
    }

    function test_diamondCut_allFacets() external {
        deployAllFacetsAndDiamondCut();

        checkStatePantosHubAfterDeployment();
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
    }

    function test_diamondCut_ByNonDeployer() external {
        dLoupe = new DiamondLoupeFacet();
        pantosRegistryFacet = new PantosRegistryFacet();
        pantosTransferFacet = new PantosTransferFacet();

        pantosHubInit = new PantosHubInit();

        // Prepare diamond cut and initializer data
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts();
        bytes memory initializerData = prepareInitializerData(
            getInitializerArgs()
        );

        vm.expectRevert("PantosHub: caller doesn't have role");
        // upgrade pantosHub diamond with facets using diamondCut
        IDiamondCut(address(pantosHubDiamond)).diamondCut(
            cut,
            address(pantosHubInit),
            initializerData
        );
    }

    function test_diamondCut_ByNonDeployerWithoutInit() external {
        dLoupe = new DiamondLoupeFacet();
        pantosRegistryFacet = new PantosRegistryFacet();
        pantosTransferFacet = new PantosTransferFacet();

        pantosHubInit = new PantosHubInit();

        // Prepare diamond cut and initializer data
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts();

        vm.expectRevert("PantosHub: caller doesn't have role");
        // upgrade pantosHub diamond with facets using diamondCut
        IDiamondCut(address(pantosHubDiamond)).diamondCut(cut, address(0), "");
    }

    function test_diamondCut_NonExistingFacet() external {
        pantosHubInit = new PantosHubInit();
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(999),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getDiamondLoupeSelectors()
            })
        );
        bytes memory initializerData = prepareInitializerData(
            getInitializerArgs()
        );

        vm.expectRevert("LibDiamondCut: New facet has no code");
        vm.prank(DEPLOYER);
        IDiamondCut(address(pantosHubDiamond)).diamondCut(
            cut,
            address(pantosHubInit),
            initializerData
        );
    }

    function test_diamondCut_NonExistingFacetWithoutInit() external {
        pantosHubInit = new PantosHubInit();
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(999),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getDiamondLoupeSelectors()
            })
        );

        vm.expectRevert("LibDiamondCut: New facet has no code");
        vm.prank(DEPLOYER);
        IDiamondCut(address(pantosHubDiamond)).diamondCut(cut, address(0), "");
    }

    function test_diamondCut_ReplaceFacetSameInterface() external {
        deployAllFacetsAndDiamondCut();
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
        initializePantosHub();
        checkStatePantosHubAfterInit();

        reDeployRegistryAndTransferFacetsAndDiamondCut();

        facets = IDiamondLoupe(address(pantosHubDiamond)).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
        checkStatePantosHubAfterInit();
    }

    function test_diamondCut_ReplaceFacetSameInterfaceBeforePantosHubInit()
        external
    {
        deployAllFacetsAndDiamondCut();
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
        checkStatePantosHubAfterDeployment();

        reDeployRegistryAndTransferFacetsAndDiamondCut();

        facets = IDiamondLoupe(address(pantosHubDiamond)).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
        checkStatePantosHubAfterDeployment();
    }

    function test_diamondCut_ReplaceFacetUpdatedInterfaceUsingRemoveAdd()
        external
    {
        deployAllFacetsAndDiamondCut();
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);

        // prepare diamond cut to replace a facet with updated interface
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](2);

        // new TransferFacetV2
        PantosTransferV2Facet pantosTransferV2Facet = new PantosTransferV2Facet();
        bytes4[] memory transferFacetSelectors = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facetFunctionSelectors(address(pantosTransferFacet));

        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(0),
                action: IDiamondCut.FacetCutAction.Remove,
                functionSelectors: transferFacetSelectors
            })
        );

        cut[1] = (
            IDiamondCut.FacetCut({
                facetAddress: address(pantosTransferV2Facet),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getPantosTransferV2Selectors()
            })
        );

        vm.prank(DEPLOYER);
        IDiamondCut(address(pantosHubDiamond)).diamondCut(cut, address(0), "");

        facets = IDiamondLoupe(address(pantosHubDiamond)).facets();

        checkFacetsAfterTransferFacetV2Update(facets, pantosTransferV2Facet);
    }

    function test_diamondCut_ReplaceFacetUpdatedInterfaceUsingReplace()
        external
    {
        deployAllFacetsAndDiamondCut();
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);

        initializePantosHub();
        // prepare diamond cut to replace a facet with updated interface
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);

        // new TransferFacetV2
        PantosTransferV2Facet pantosTransferV2Facet = new PantosTransferV2Facet();

        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(0),
                action: IDiamondCut.FacetCutAction.Remove,
                functionSelectors: getPantosTransferV2SelectorsToRemove()
            })
        );

        cut[1] = (
            IDiamondCut.FacetCut({
                facetAddress: address(pantosTransferV2Facet),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getPantosTransferV2SelectorsToAdd()
            })
        );

        cut[2] = (
            IDiamondCut.FacetCut({
                facetAddress: address(pantosTransferV2Facet),
                action: IDiamondCut.FacetCutAction.Replace,
                functionSelectors: getPantosTransferV2SelectorsToReplace()
            })
        );

        vm.prank(DEPLOYER);
        IDiamondCut(address(pantosHubDiamond)).diamondCut(cut, address(0), "");

        facets = IDiamondLoupe(address(pantosHubDiamond)).facets();

        assertEq(facets[3].facetAddress, address(pantosTransferV2Facet));
        assertEq(facets[3].functionSelectors.length, 4);
        // order of functionSelectors are not preserved
    }

    function test_diamondCut_addNewFacet() external {
        deployAllFacetsAndDiamondCut();
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
        initializePantosHub();
        checkStatePantosHubAfterInit();

        deployNewDummyFacetsAndDiamondCut();
        DummyFacet wrappedDummyFacet = DummyFacet(address(pantosHubDiamond));
        wrappedDummyFacet.setNewAddress(address(999));
        wrappedDummyFacet.setNewUint(999);
        wrappedDummyFacet.setNewMapping(address(999));

        // checking storage state integrity after modifying new fields
        assertEq(wrappedDummyFacet.getNewAddress(), address(999));
        assertTrue(
            wrappedDummyFacet.isNewMappingEntryForAddress(address(999))
        );
        assertEq(wrappedDummyFacet.getNewUint(), 999);
        checkStatePantosHubAfterInit();

        facets = IDiamondLoupe(address(pantosHubDiamond)).facets();
        assertEq(facets.length, 5);
        checkInitialCutFacets(facets);
        assertEq(facets[4].functionSelectors, getDummyFacetSelectors());
    }

    function test_diamondCut_addNewFacetUsingReinitilizer() external {
        deployAllFacetsAndDiamondCut();
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
        initializePantosHub();
        checkStatePantosHubAfterInit();

        deployNewDummyFacetsAndDiamondCutUsingReinitializer();
        DummyFacet wrappedDummyFacet = DummyFacet(address(pantosHubDiamond));

        // checking storage state integrity
        assertEq(wrappedDummyFacet.getNewAddress(), address(9999));
        assertTrue(
            wrappedDummyFacet.isNewMappingEntryForAddress(address(9998))
        );
        assertEq(wrappedDummyFacet.getNewUint(), 9997);
        checkStatePantosHubAfterInit();

        facets = IDiamondLoupe(address(pantosHubDiamond)).facets();
        assertEq(facets.length, 5);
        checkInitialCutFacets(facets);
        assertEq(facets[4].functionSelectors, getDummyFacetSelectors());
    }

    function test_diamondCut_addNewFacetUsingReinitilizerTwice() external {
        deployAllFacetsAndDiamondCut();
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
        initializePantosHub();
        checkStatePantosHubAfterInit();

        deployNewDummyFacetsAndDiamondCutUsingReinitializer();
        DummyFacet wrappedDummyFacet = DummyFacet(address(pantosHubDiamond));

        // reusing reinit
        dummyFacet = new DummyFacet();

        // prepare diamond cut
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(dummyFacet),
                action: IDiamondCut.FacetCutAction.Replace,
                functionSelectors: getDummyFacetSelectors()
            })
        );

        PantosHubReinit pantosHubReinit = new PantosHubReinit();

        PantosHubReinit.Args memory args = PantosHubReinit.Args({
            newAddress: address(8888),
            newMappingAddress: address(8888),
            newUint: 8888
        });

        bytes memory initializerData = abi.encodeCall(
            PantosHubReinit.init,
            (args)
        );

        vm.expectRevert("PantosHubRenit: contract is already initialized");
        vm.prank(DEPLOYER);
        IDiamondCut(address(pantosHubDiamond)).diamondCut(
            cut,
            address(pantosHubReinit),
            initializerData
        );

        // checking storage state integrity
        assertEq(wrappedDummyFacet.getNewAddress(), address(9999));
        assertTrue(
            wrappedDummyFacet.isNewMappingEntryForAddress(address(9998))
        );
        assertEq(wrappedDummyFacet.getNewUint(), 9997);
        checkStatePantosHubAfterInit();

        facets = IDiamondLoupe(address(pantosHubDiamond)).facets();
        assertEq(facets.length, 5);
        checkInitialCutFacets(facets);
        assertEq(facets[4].functionSelectors, getDummyFacetSelectors());
    }

    function test_diamondCut_removeFacet() external {
        deployAllFacetsAndDiamondCut();
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facets();
        assertEq(facets.length, 4);
        initializePantosHub();
        deployNewDummyFacetsAndDiamondCut();
        checkStatePantosHubAfterInit();
        facets = IDiamondLoupe(address(pantosHubDiamond)).facets();
        assertEq(facets.length, 5);
        checkInitialCutFacets(facets);
        assertEq(facets[4].functionSelectors, getDummyFacetSelectors());

        // prepare diamond cut to remove a facet
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(0),
                action: IDiamondCut.FacetCutAction.Remove,
                functionSelectors: getDummyFacetSelectors()
            })
        );
        vm.prank(DEPLOYER);
        IDiamondCut(address(pantosHubDiamond)).diamondCut(cut, address(0), "");

        facets = IDiamondLoupe(address(pantosHubDiamond)).facets();
        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
        checkStatePantosHubAfterInit();
    }

    function test_loupe_facets_ByDeployer() external {
        deployAllFacetsAndDiamondCut();

        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facets();

        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
    }

    function test_loupe_facets_BeforePantosHubInit() external {
        deployAllFacetsAndDiamondCut();

        vm.startPrank(address(123));
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facets();

        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
    }

    function test_loupe_facets_AfterPantosHubInit() external {
        deployAllFacetsAndDiamondCut();
        initializePantosHub();

        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facets();

        assertEq(facets.length, 4);
        checkInitialCutFacets(facets);
    }

    function test_loupe_facetFunctionSelectors() external {
        deployAllFacetsAndDiamondCut();

        vm.startPrank(address(123));
        bytes4[] memory facetFunctionSelectors = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facetFunctionSelectors(address(pantosRegistryFacet));

        assertEq(facetFunctionSelectors, getPantosRegistrySelectors());
    }

    function test_loupe_facetFunctionSelectors_InvalidFacet() external {
        deployAllFacetsAndDiamondCut();

        vm.startPrank(address(123));
        bytes4[] memory facetFunctionSelectors = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facetFunctionSelectors(address(111));
        assertEq(facetFunctionSelectors.length, 0);
    }

    function test_loupe_facetFunctionSelectors_0Facet() external {
        deployAllFacetsAndDiamondCut();

        vm.startPrank(address(123));
        bytes4[] memory facetFunctionSelectors = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facetFunctionSelectors(address(0));
        assertEq(facetFunctionSelectors.length, 0);
    }

    function test_loupe_facetAddresses() external {
        deployAllFacetsAndDiamondCut();

        vm.startPrank(address(123));
        address[] memory facetAddresses = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facetAddresses();

        checkInitialCutFacetAdresses(facetAddresses);
    }

    function test_loupe_facetAddresses_ByDeployer() external {
        deployAllFacetsAndDiamondCut();

        vm.startPrank(address(123));
        address[] memory facetAddresses = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facetAddresses();
        checkInitialCutFacetAdresses(facetAddresses);
    }

    function test_loupe_facetAddresses_BeforePantosHubInit() external {
        deployAllFacetsAndDiamondCut();

        vm.startPrank(address(123));
        address[] memory facetAddresses = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facetAddresses();
        checkInitialCutFacetAdresses(facetAddresses);
    }

    function test_loupe_facetAddresses_AfterPantosHubInit() external {
        deployAllFacetsAndDiamondCut();
        initializePantosHub();

        address[] memory facetAddresses = IDiamondLoupe(
            address(pantosHubDiamond)
        ).facetAddresses();
        checkInitialCutFacetAdresses(facetAddresses);
    }

    function test_loupe_facetAddress_BeforePantosHubInit() external {
        deployAllFacetsAndDiamondCut();

        address facetAddress = IDiamondLoupe(address(pantosHubDiamond))
            .facetAddress(IDiamondCut.diamondCut.selector);
        assertEq(facetAddress, address(dCutFacet));

        bytes4[] memory selectors = getDiamondLoupeSelectors();
        checkLoupeFacetAddressForSelectors(selectors, address(dLoupe));

        selectors = getPantosRegistrySelectors();
        checkLoupeFacetAddressForSelectors(
            selectors,
            address(pantosRegistryFacet)
        );

        selectors = getPantosTransferSelectors();
        checkLoupeFacetAddressForSelectors(
            selectors,
            address(pantosTransferFacet)
        );
    }

    function test_loupe_facetAddress_AfterPantosHubInit() external {
        deployAllFacetsAndDiamondCut();
        initializePantosHub();

        address facetAddress = IDiamondLoupe(address(pantosHubDiamond))
            .facetAddress(IDiamondCut.diamondCut.selector);
        assertEq(facetAddress, address(dCutFacet));

        bytes4[] memory selectors = getDiamondLoupeSelectors();
        checkLoupeFacetAddressForSelectors(selectors, address(dLoupe));

        selectors = getPantosRegistrySelectors();
        checkLoupeFacetAddressForSelectors(
            selectors,
            address(pantosRegistryFacet)
        );

        selectors = getPantosTransferSelectors();
        checkLoupeFacetAddressForSelectors(
            selectors,
            address(pantosTransferFacet)
        );
    }

    function test_loupe_facetAddress_UnknownSelector() external {
        deployAllFacetsAndDiamondCut();
        initializePantosHub();

        address facetAddress = IDiamondLoupe(address(pantosHubDiamond))
            .facetAddress(DummyFacet.getNewAddress.selector);
        assertEq(facetAddress, address(0));
    }

    function deployNewDummyFacetsAndDiamondCut() public {
        dummyFacet = new DummyFacet();

        // prepare diamond cut
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(dummyFacet),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getDummyFacetSelectors()
            })
        );

        vm.prank(DEPLOYER);
        // upgrade pantosHub diamond with facets using diamondCut
        IDiamondCut(address(pantosHubDiamond)).diamondCut(cut, address(0), "");
    }

    function deployNewDummyFacetsAndDiamondCutUsingReinitializer() public {
        dummyFacet = new DummyFacet();

        // prepare diamond cut
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(dummyFacet),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: getDummyFacetSelectors()
            })
        );

        PantosHubReinit pantosHubReinit = new PantosHubReinit();

        PantosHubReinit.Args memory args = PantosHubReinit.Args({
            newAddress: address(9999),
            newMappingAddress: address(9998),
            newUint: 9997
        });

        bytes memory initializerData = abi.encodeCall(
            PantosHubReinit.init,
            (args)
        );
        vm.prank(DEPLOYER);
        // upgrade pantosHub diamond with facets using diamondCut
        IDiamondCut(address(pantosHubDiamond)).diamondCut(
            cut,
            address(pantosHubReinit),
            initializerData
        );
    }

    function checkInitialCutFacetAdresses(
        address[] memory facetAddresses
    ) public view {
        assertEq(facetAddresses.length, 4);
        assertEq(facetAddresses[0], address(dCutFacet));
        assertEq(facetAddresses[1], address(dLoupe));
        assertEq(facetAddresses[2], address(pantosRegistryFacet));
        assertEq(facetAddresses[3], address(pantosTransferFacet));
    }

    function checkLoupeFacetAddressForSelectors(
        bytes4[] memory selectors,
        address expecterFacetAddress
    ) public view {
        for (uint256 i; i < selectors.length; i++) {
            address facetAddress = IDiamondLoupe(address(pantosHubDiamond))
                .facetAddress(selectors[i]);
            assertEq(facetAddress, expecterFacetAddress);
        }
    }

    function checkInitialCutFacets(
        IDiamondLoupe.Facet[] memory facets
    ) public view {
        assertEq(facets[0].facetAddress, address(dCutFacet));
        assertEq(facets[1].facetAddress, address(dLoupe));
        assertEq(facets[2].facetAddress, address(pantosRegistryFacet));
        assertEq(facets[3].facetAddress, address(pantosTransferFacet));

        assertEq(facets[0].functionSelectors.length, 1);
        assertEq(
            facets[0].functionSelectors[0],
            IDiamondCut.diamondCut.selector
        );

        assertEq(facets[1].functionSelectors, getDiamondLoupeSelectors());
        assertEq(facets[2].functionSelectors, getPantosRegistrySelectors());
        assertEq(facets[3].functionSelectors, getPantosTransferSelectors());
    }

    function checkFacetsAfterTransferFacetV2Update(
        IDiamondLoupe.Facet[] memory facets,
        PantosTransferV2Facet transferFacetV2
    ) public view {
        assertEq(facets[0].facetAddress, address(dCutFacet));
        assertEq(facets[1].facetAddress, address(dLoupe));
        assertEq(facets[2].facetAddress, address(pantosRegistryFacet));
        assertEq(facets[3].facetAddress, address(transferFacetV2));

        assertEq(facets[0].functionSelectors.length, 1);
        assertEq(
            facets[0].functionSelectors[0],
            IDiamondCut.diamondCut.selector
        );

        assertEq(facets[1].functionSelectors, getDiamondLoupeSelectors());
        assertEq(facets[2].functionSelectors, getPantosRegistrySelectors());
        assertEq(facets[3].functionSelectors, getPantosTransferV2Selectors());
    }

    function getDummyFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = DummyFacet.setNewAddress.selector;
        selectors[1] = DummyFacet.setNewMapping.selector;
        selectors[2] = DummyFacet.setNewUint.selector;
        selectors[3] = DummyFacet.getNewAddress.selector;
        selectors[4] = DummyFacet.isNewMappingEntryForAddress.selector;
        selectors[5] = DummyFacet.getNewUint.selector;
        return selectors;
    }

    function getPantosTransferV2Selectors()
        public
        pure
        returns (bytes4[] memory)
    {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = IPantosTransferV2.transfer.selector;
        selectors[1] = IPantosTransferV2.transferFromV2.selector;
        selectors[2] = IPantosTransferV2.transferToV2.selector;
        selectors[3] = IPantosTransferV2.isValidSenderNonce.selector;

        return selectors;
    }

    function getPantosTransferV2SelectorsToAdd()
        public
        pure
        returns (bytes4[] memory)
    {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = IPantosTransferV2.transferFromV2.selector;
        selectors[1] = IPantosTransferV2.transferToV2.selector;
        return selectors;
    }

    function getPantosTransferV2SelectorsToRemove()
        public
        pure
        returns (bytes4[] memory)
    {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = IPantosTransfer.transferFrom.selector;
        selectors[1] = IPantosTransfer.transferTo.selector;
        selectors[2] = IPantosTransfer.verifyTransfer.selector;
        selectors[3] = IPantosTransfer.verifyTransferFrom.selector;
        selectors[4] = IPantosTransfer.verifyTransferTo.selector;
        selectors[5] = IPantosTransfer.getNextTransferId.selector;
        return selectors;
    }

    function getPantosTransferV2SelectorsToReplace()
        public
        pure
        returns (bytes4[] memory)
    {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = IPantosTransferV2.transfer.selector;
        selectors[1] = IPantosTransferV2.isValidSenderNonce.selector;
        return selectors;
    }
}
