// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {IDiamondCut} from "@diamond/interfaces/IDiamondCut.sol";

import {IPantosHub} from "../src/interfaces/IPantosHub.sol";
import {PantosRegistryFacet} from "../src/facets/PantosRegistryFacet.sol";
import {PantosHubInit} from "../src/upgradeInitializers/PantosHubInit.sol";

import {PantosHubDeployer} from "./PantosHubDeployer.t.sol";

contract PantosHubInitTest is PantosHubDeployer {
    function setUp() public {
        deployPantosHubProxyAndDiamondCutFacet();
    }

    function test_init() external {
        deployAllFacetsAndDiamondCut();

        checkStatePantosHubAfterDeployment();
    }

    function test_init_Twice() external {
        deployAllFacets();
        pantosHubInit = new PantosHubInit();
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts();
        bytes memory initializerData = prepareInitializerData(
            getInitializerArgs()
        );

        IDiamondCut(address(pantosHubDiamond)).diamondCut(
            cut,
            address(pantosHubInit),
            initializerData
        );
        // wrap in IPantosHub ABI to support easier calls
        pantosHubProxy = IPantosHub(address(pantosHubDiamond));

        // Prepare another valid diamond cut
        IDiamondCut.FacetCut[] memory cut2 = new IDiamondCut.FacetCut[](1);
        // PantosRegistryFacet
        pantosRegistryFacet = new PantosRegistryFacet();
        cut2[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(pantosRegistryFacet),
                action: IDiamondCut.FacetCutAction.Replace,
                functionSelectors: getPantosRegistrySelectors()
            })
        );

        vm.expectRevert("PantosHubInit: contract is already initialized");
        IDiamondCut(address(pantosHubDiamond)).diamondCut(
            cut2,
            address(pantosHubInit),
            initializerData
        );

        checkStatePantosHubAfterDeployment();
    }

    function test_init_EmptyBlockchainName() external {
        deployAllFacets();
        pantosHubInit = new PantosHubInit();
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts();
        PantosHubInit.Args memory args = getInitializerArgs();
        args.blockchainName = "";
        bytes memory initializerData = prepareInitializerData(args);
        vm.expectRevert("PantosHubInit: blockchain name must not be empty");

        IDiamondCut(address(pantosHubDiamond)).diamondCut(
            cut,
            address(pantosHubInit),
            initializerData
        );
    }

    function test_init_InvalidFeeFactor() external {
        deployAllFacets();
        pantosHubInit = new PantosHubInit();
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts();
        PantosHubInit.Args memory args = getInitializerArgs();
        args.feeFactor = 0;
        bytes memory initializerData = prepareInitializerData(args);
        vm.expectRevert("PantosHubInit: newFactor must be >= 1");

        IDiamondCut(address(pantosHubDiamond)).diamondCut(
            cut,
            address(pantosHubInit),
            initializerData
        );
    }

    function test_init_FeeFactorValidFromNotLargeEnough() external {
        deployAllFacets();
        pantosHubInit = new PantosHubInit();
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts();
        PantosHubInit.Args memory args = getInitializerArgs();
        args.feeFactorValidFrom = block.timestamp - 1;
        bytes memory initializerData = prepareInitializerData(args);
        vm.expectRevert(
            "PantosHubInit: validFrom must be larger than "
            "(block timestamp + minimum update period)"
        );

        IDiamondCut(address(pantosHubDiamond)).diamondCut(
            cut,
            address(pantosHubInit),
            initializerData
        );
    }

    function test_init_CalledDirectlyBeforeDiamondCut() external {
        deployAllFacets();
        pantosHubInit = new PantosHubInit();

        pantosHubInit.init(getInitializerArgs());

        // should allow normal init
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts();
        bytes memory initializerData = prepareInitializerData(
            getInitializerArgs()
        );

        IDiamondCut(address(pantosHubDiamond)).diamondCut(
            cut,
            address(pantosHubInit),
            initializerData
        );
        // wrap in IPantosHub ABI to support easier calls
        pantosHubProxy = IPantosHub(address(pantosHubDiamond));
        checkStatePantosHubAfterDeployment();
    }

    function test_init_CalledDirectlyAfterDiamondCut() external {
        deployAllFacets();
        pantosHubInit = new PantosHubInit();

        // should allow normal init
        IDiamondCut.FacetCut[] memory cut = prepareFacetCuts();
        bytes memory initializerData = prepareInitializerData(
            getInitializerArgs()
        );

        IDiamondCut(address(pantosHubDiamond)).diamondCut(
            cut,
            address(pantosHubInit),
            initializerData
        );
        // wrap in IPantosHub ABI to support easier calls
        pantosHubProxy = IPantosHub(address(pantosHubDiamond));
        checkStatePantosHubAfterDeployment();

        pantosHubInit.init(getInitializerArgs());

        checkStatePantosHubAfterDeployment();
    }
}
