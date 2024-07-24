// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC173} from "@diamond/interfaces/IERC173.sol";
import {console2} from "forge-std/console2.sol";

import {PantosTypes} from "../src/interfaces/PantosTypes.sol";
import {IPantosForwarder} from "../src/interfaces/IPantosForwarder.sol";
import {IPantosRegistry} from "../src/interfaces/IPantosRegistry.sol";
import {IPantosTransfer} from "../src/interfaces/IPantosTransfer.sol";
import {PantosBaseToken} from "../src/PantosBaseToken.sol";
import {PantosForwarder} from "../src/PantosForwarder.sol";

import {PantosHubDeployer} from "./PantosHubDeployer.t.sol";

contract PantosHubTest is PantosHubDeployer {
    function setUp() public {
        vm.warp(BLOCK_TIMESTAMP);
        deployPantosHub();
    }

    function test_SetUpState() external {
        checkStatePantosHubAfterDeployment();
    }

    function test_PantosHubInitialization() external {
        initializePantosHub();
        checkStatePantosHubAfterInit();
    }

    function test_pause_AfterInitialization() external {
        initializePantosHub();
        vm.expectEmit(address(pantosHubProxy));
        emit IPantosRegistry.Paused(deployer());

        pantosHubProxy.pause();

        assertTrue(pantosHubProxy.paused());
    }

    function test_pause_WhenPaused() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.pause.selector
        );

        whenNotPausedTest(address(pantosHubProxy), calldata_);
    }

    function test_pause_ByNonOwner() external {
        initializePantosHub();
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.pause.selector
        );

        onlyOwnerTest(address(pantosHubProxy), calldata_);
    }

    function test_unpause_AfterDeploy() external {
        _initializePantosHubValues();
        vm.expectEmit(address(pantosHubProxy));
        emit IPantosRegistry.Unpaused(deployer());

        pantosHubProxy.unpause();

        assertFalse(pantosHubProxy.paused());
    }

    function test_unpause_WhenNotPaused() external {
        initializePantosHub();
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.unpause.selector
        );

        whenPausedTest(address(pantosHubProxy), calldata_);
    }

    function test_unpause_ByNonOwner() external {
        pantosHubProxy.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.unpause.selector
        );

        onlyOwnerTest(address(pantosHubProxy), calldata_);
    }

    function test_unpause_WithNoForwarderSet() external {
        vm.expectRevert(
            abi.encodePacked("PantosHub: PantosForwarder has not been set")
        );

        pantosHubProxy.unpause();
    }

    function test_unpause_WithNoPantosTokenSet() external {
        pantosHubProxy.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        vm.expectRevert(
            abi.encodePacked("PantosHub: PantosToken has not been set")
        );

        pantosHubProxy.unpause();
    }

    function test_unpause_WithNoPrimaryValidatorNodeSet() external {
        pantosHubProxy.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        mockPandasToken_getOwner(PANTOS_TOKEN_ADDRESS, deployer());
        pantosHubProxy.setPantosToken(PANTOS_TOKEN_ADDRESS);
        vm.expectRevert(
            abi.encodePacked(
                "PantosHub: primary validator node has not been set"
            )
        );

        pantosHubProxy.unpause();
    }

    function test_setPantosForwarder() external {
        vm.expectEmit(address(pantosHubProxy));
        emit IPantosRegistry.PantosForwarderSet(PANTOS_FORWARDER_ADDRESS);

        pantosHubProxy.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);

        assertEq(
            pantosHubProxy.getPantosForwarder(),
            PANTOS_FORWARDER_ADDRESS
        );
    }

    function test_setPantosForwarder_WhenNotPaused() public {
        initializePantosHub();
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.setPantosForwarder.selector,
            PANTOS_FORWARDER_ADDRESS
        );

        whenPausedTest(address(pantosHubProxy), calldata_);
    }

    function test_setPantosForwarder_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.setPantosForwarder.selector,
            PANTOS_FORWARDER_ADDRESS
        );

        onlyOwnerTest(address(pantosHubProxy), calldata_);
    }

    function test_setPantosForwarder_WithForwarderAddress0() external {
        vm.expectRevert(
            abi.encodePacked(
                "PantosHub: PantosForwarder must not be the zero account"
            )
        );

        pantosHubProxy.setPantosForwarder(ADDRESS_ZERO);
    }

    function test_setPantosToken() external {
        mockPandasToken_getOwner(PANTOS_TOKEN_ADDRESS, deployer());
        vm.expectEmit(address(pantosHubProxy));
        emit IPantosRegistry.PantosTokenSet(PANTOS_TOKEN_ADDRESS);

        pantosHubProxy.setPantosToken(PANTOS_TOKEN_ADDRESS);

        assertEq(pantosHubProxy.getPantosToken(), PANTOS_TOKEN_ADDRESS);
    }

    function test_setPantosToken_WhenNotPaused() external {
        initializePantosHub();
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.setPantosToken.selector,
            PANTOS_TOKEN_ADDRESS
        );

        whenPausedTest(address(pantosHubProxy), calldata_);
    }

    function test_setPantosToken_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.setPantosToken.selector,
            PANTOS_TOKEN_ADDRESS
        );

        onlyOwnerTest(address(pantosHubProxy), calldata_);
    }

    function test_setPantosToken_WithPantosToken0() external {
        vm.expectRevert("PantosHub: PantosToken must not be the zero account");

        pantosHubProxy.setPantosToken(ADDRESS_ZERO);
    }

    function test_setPantosToken_AlreadySet() external {
        mockPandasToken_getOwner(PANTOS_TOKEN_ADDRESS, deployer());
        pantosHubProxy.setPantosToken(PANTOS_TOKEN_ADDRESS);
        vm.expectRevert("PantosHub: PantosToken already set");

        pantosHubProxy.setPantosToken(PANTOS_TOKEN_ADDRESS);
    }

    function test_setPrimaryValidatorNode() external {
        vm.expectEmit(address(pantosHubProxy));
        emit IPantosRegistry.PrimaryValidatorNodeUpdated(validatorAddress);

        pantosHubProxy.setPrimaryValidatorNode(validatorAddress);

        assertEq(pantosHubProxy.getPrimaryValidatorNode(), validatorAddress);
    }

    function test_setPrimaryValidatorNode_WhenNotPaused() public {
        initializePantosHub();
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.setPrimaryValidatorNode.selector,
            validatorAddress
        );

        whenPausedTest(address(pantosHubProxy), calldata_);
    }

    function test_setPrimaryValidatorNode_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.setPrimaryValidatorNode.selector,
            validatorAddress
        );

        onlyOwnerTest(address(pantosHubProxy), calldata_);
    }

    function test_registerBlockchain() external {
        vm.expectEmit();
        emit IPantosRegistry.BlockchainRegistered(
            uint256(otherBlockchain.blockchainId)
        );

        registerOtherBlockchainAtPantosHub();

        PantosTypes.BlockchainRecord
            memory otherBlockchainRecord = pantosHubProxy.getBlockchainRecord(
                uint256(otherBlockchain.blockchainId)
            );
        PantosTypes.ValidatorFeeRecord
            memory otherBlockchainValidatorFeeRecord = pantosHubProxy
                .getValidatorFeeRecord(uint256(otherBlockchain.blockchainId));
        assertEq(otherBlockchainRecord.name, otherBlockchain.name);
        assertEq(otherBlockchainRecord.active, true);
        assertEq(pantosHubProxy.getNumberBlockchains(), 2);
        assertEq(pantosHubProxy.getNumberActiveBlockchains(), 2);
        assertEq(
            otherBlockchainValidatorFeeRecord.newFactor,
            otherBlockchain.feeFactor
        );
        assertEq(otherBlockchainValidatorFeeRecord.oldFactor, 0);
        assertEq(
            otherBlockchainValidatorFeeRecord.validFrom,
            FEE_FACTOR_VALID_FROM
        );
    }

    function test_registerBlockchain_AgainAfterUnregistration() external {
        registerOtherBlockchainAtPantosHub();
        pantosHubProxy.unregisterBlockchain(
            uint256(otherBlockchain.blockchainId)
        );
        vm.expectEmit();
        emit IPantosRegistry.BlockchainRegistered(
            uint256(otherBlockchain.blockchainId)
        );

        registerOtherBlockchainAtPantosHub();

        PantosTypes.BlockchainRecord
            memory otherBlockchainRecord = pantosHubProxy.getBlockchainRecord(
                uint256(otherBlockchain.blockchainId)
            );
        PantosTypes.ValidatorFeeRecord
            memory otherBlockchainValidatorFeeRecord = pantosHubProxy
                .getValidatorFeeRecord(uint256(otherBlockchain.blockchainId));
        assertEq(otherBlockchainRecord.name, otherBlockchain.name);
        assertEq(otherBlockchainRecord.active, true);
        assertEq(pantosHubProxy.getNumberBlockchains(), 2);
        assertEq(pantosHubProxy.getNumberActiveBlockchains(), 2);
        assertEq(
            otherBlockchainValidatorFeeRecord.newFactor,
            otherBlockchain.feeFactor
        );
        assertEq(otherBlockchainValidatorFeeRecord.oldFactor, 0);
        assertEq(
            otherBlockchainValidatorFeeRecord.validFrom,
            FEE_FACTOR_VALID_FROM
        );
    }

    function test_registerBlockchain_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.registerBlockchain.selector,
            uint256(otherBlockchain.blockchainId),
            otherBlockchain.name,
            otherBlockchain.feeFactor,
            FEE_FACTOR_VALID_FROM
        );

        onlyOwnerTest(address(pantosHubProxy), calldata_);
    }

    function test_registerBlockchain_WithEmptyName() external {
        vm.expectRevert("PantosHub: blockchain name must not be empty");

        pantosHubProxy.registerBlockchain(
            uint256(otherBlockchain.blockchainId),
            "",
            otherBlockchain.feeFactor,
            FEE_FACTOR_VALID_FROM
        );
    }

    function test_registerBlockchain_AlreadyRegistered() external {
        registerOtherBlockchainAtPantosHub();
        vm.expectRevert("PantosHub: blockchain already registered");

        registerOtherBlockchainAtPantosHub();
    }

    function test_unregisterBlockchain() external {
        registerOtherBlockchainAtPantosHub();
        vm.expectEmit();
        emit IPantosRegistry.BlockchainUnregistered(
            uint256(otherBlockchain.blockchainId)
        );

        pantosHubProxy.unregisterBlockchain(
            uint256(otherBlockchain.blockchainId)
        );

        PantosTypes.BlockchainRecord
            memory otherBlockchainRecord = pantosHubProxy.getBlockchainRecord(
                uint256(otherBlockchain.blockchainId)
            );
        assertEq(pantosHubProxy.getNumberActiveBlockchains(), 1);
        assertEq(pantosHubProxy.getNumberBlockchains(), 2);
        assertEq(otherBlockchainRecord.name, otherBlockchain.name);
        assertEq(otherBlockchainRecord.active, false);
    }

    function test_unregisterBlockchain_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.unregisterBlockchain.selector,
            uint256(otherBlockchain.blockchainId)
        );

        onlyOwnerTest(address(pantosHubProxy), calldata_);
    }

    function test_unregisterBlockchain_WithCurrentBlockchain() external {
        vm.expectRevert(
            "PantosHub: blockchain ID must not be the current blockchain ID"
        );

        pantosHubProxy.unregisterBlockchain(
            uint256(thisBlockchain.blockchainId)
        );
    }

    function test_unregisterBlockchain_WhenBlockchainNotRegistered() external {
        vm.expectRevert("PantosHub: blockchain must be active");

        pantosHubProxy.unregisterBlockchain(
            uint256(type(BlockchainId).max) + 1
        );
    }

    function test_unregisterBlockchain_AlreadyUnregistered() external {
        registerOtherBlockchainAtPantosHub();
        pantosHubProxy.unregisterBlockchain(
            uint256(otherBlockchain.blockchainId)
        );
        vm.expectRevert("PantosHub: blockchain must be active");

        pantosHubProxy.unregisterBlockchain(
            uint256(otherBlockchain.blockchainId)
        );
    }

    function test_updateBlockchainName() external {
        string memory newBlockchainName = "new name";
        vm.expectEmit();
        emit IPantosRegistry.BlockchainNameUpdated(
            uint256(thisBlockchain.blockchainId)
        );

        pantosHubProxy.updateBlockchainName(
            uint256(thisBlockchain.blockchainId),
            newBlockchainName
        );

        assertEq(
            pantosHubProxy
                .getBlockchainRecord(uint256(thisBlockchain.blockchainId))
                .name,
            newBlockchainName
        );
    }

    function test_updateBlockchainName_WhenNotPaused() external {
        initializePantosHub();
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.updateBlockchainName.selector,
            uint256(thisBlockchain.blockchainId),
            "new name"
        );

        whenPausedTest(address(pantosHubProxy), calldata_);
    }

    function test_updateBlockchainName_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.updateBlockchainName.selector,
            uint256(thisBlockchain.blockchainId),
            "new name"
        );

        onlyOwnerTest(address(pantosHubProxy), calldata_);
    }

    function test_updateBlockchainName_WithEmptyName() external {
        vm.expectRevert("PantosHub: blockchain name must not be empty");

        pantosHubProxy.updateBlockchainName(
            uint256(thisBlockchain.blockchainId),
            ""
        );
    }

    function test_updateBlockchainName_WhenBlockchainNotRegistered() external {
        vm.expectRevert("PantosHub: blockchain must be active");

        pantosHubProxy.updateBlockchainName(
            uint256(type(BlockchainId).max) + 1,
            "new name"
        );
    }

    function test_updateBlockchainName_WhenBlockchainUnregistered() external {
        registerOtherBlockchainAtPantosHub();
        pantosHubProxy.unregisterBlockchain(
            uint256(otherBlockchain.blockchainId)
        );
        vm.expectRevert("PantosHub: blockchain must be active");

        pantosHubProxy.updateBlockchainName(
            uint256(otherBlockchain.blockchainId),
            "new name"
        );
    }

    function test_updateFeeFactor_oldFactorNotValidYet() external {
        initializePantosHub();
        uint256 thisBlockchainId = uint256(thisBlockchain.blockchainId);
        uint256 newFactor = thisBlockchain.feeFactor + 100;
        uint256 validFrom = FEE_FACTOR_VALID_FROM + 100;
        pantosHubProxy.updateFeeFactor(thisBlockchainId, newFactor, validFrom);
        vm.expectEmit();
        emit IPantosRegistry.ValidatorFeeUpdated(
            thisBlockchainId,
            0,
            newFactor,
            validFrom
        );

        pantosHubProxy.updateFeeFactor(thisBlockchainId, newFactor, validFrom);

        PantosTypes.ValidatorFeeRecord
            memory validatorFeeRecord = pantosHubProxy.getValidatorFeeRecord(
                thisBlockchainId
            );
        assertEq(validatorFeeRecord.newFactor, newFactor);
        assertEq(validatorFeeRecord.oldFactor, 0);
        assertEq(validatorFeeRecord.validFrom, validFrom);
    }

    function test_updateFeeFactor_oldFactorValid() external {
        vm.warp(FEE_FACTOR_VALID_FROM);
        initializePantosHub();
        uint256 thisBlockchainId = uint256(thisBlockchain.blockchainId);
        uint256 newFactor = thisBlockchain.feeFactor + 100;
        uint256 validFrom = FEE_FACTOR_VALID_FROM + 100;
        pantosHubProxy.updateFeeFactor(thisBlockchainId, newFactor, validFrom);
        vm.expectEmit();
        emit IPantosRegistry.ValidatorFeeUpdated(
            thisBlockchainId,
            thisBlockchain.feeFactor,
            newFactor,
            validFrom
        );

        pantosHubProxy.updateFeeFactor(thisBlockchainId, newFactor, validFrom);

        PantosTypes.ValidatorFeeRecord
            memory validatorFeeRecord = pantosHubProxy.getValidatorFeeRecord(
                thisBlockchainId
            );
        assertEq(validatorFeeRecord.newFactor, newFactor);
        assertEq(validatorFeeRecord.oldFactor, thisBlockchain.feeFactor);
        assertEq(validatorFeeRecord.validFrom, validFrom);
    }

    function test_updateFeeFactor_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.updateFeeFactor.selector,
            uint256(thisBlockchain.blockchainId),
            0,
            0
        );

        onlyOwnerTest(address(pantosHubProxy), calldata_);
    }

    function test_updateFeeFactor_WithUnsupportedBlockchain() external {
        initializePantosHub();
        vm.expectRevert("PantosHub: blockchain ID not supported");

        pantosHubProxy.updateFeeFactor(
            uint256(type(BlockchainId).max) + 1,
            0,
            0
        );
    }

    function test_updateFeeFactor_WithFeeFactor1() external {
        initializePantosHub();
        vm.expectRevert("PantosHub: newFactor must be >= 1");

        pantosHubProxy.updateFeeFactor(
            uint256(thisBlockchain.blockchainId),
            0,
            0
        );
    }

    function test_updateFeeFactor_ValidFromNotLargeEnough() external {
        initializePantosHub();
        vm.expectRevert(
            "PantosHub: validFrom must be larger than "
            "(block timestamp + minimum update period)"
        );

        pantosHubProxy.updateFeeFactor(
            uint256(thisBlockchain.blockchainId),
            1,
            block.timestamp - 1
        );
    }

    function test_setUnbondingPeriodServiceNodeDeposit() external {
        uint256 unbondingPeriodServiceNodeDeposit = 1;
        vm.expectEmit();
        emit IPantosRegistry.UnbondingPeriodServiceNodeDepositUpdated(
            unbondingPeriodServiceNodeDeposit
        );

        pantosHubProxy.setUnbondingPeriodServiceNodeDeposit(
            unbondingPeriodServiceNodeDeposit
        );

        assertEq(
            pantosHubProxy.getUnbondingPeriodServiceNodeDeposit(),
            unbondingPeriodServiceNodeDeposit
        );
    }

    function test_setUnbondingPeriodServiceNodeDeposit_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.setUnbondingPeriodServiceNodeDeposit.selector,
            1
        );

        onlyOwnerTest(address(pantosHubProxy), calldata_);
    }

    function test_setMinimumServiceNodeDeposit() external {
        uint256 minimumServiceNodeDeposit = 1;
        vm.expectEmit();
        emit IPantosRegistry.MinimumServiceNodeDepositUpdated(
            minimumServiceNodeDeposit
        );

        pantosHubProxy.setMinimumServiceNodeDeposit(minimumServiceNodeDeposit);

        assertEq(
            pantosHubProxy.getMinimumServiceNodeDeposit(),
            minimumServiceNodeDeposit
        );
    }

    function test_setMinimumServiceNodeDeposit_WhenNotPaused() external {
        initializePantosHub();
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.setMinimumServiceNodeDeposit.selector,
            1
        );

        whenPausedTest(address(pantosHubProxy), calldata_);
    }

    function test_setMinimumServiceNodeDeposit_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.setMinimumServiceNodeDeposit.selector,
            1
        );

        onlyOwnerTest(address(pantosHubProxy), calldata_);
    }

    function test_setMinimumValidatorFeeUpdatePeriod() external {
        uint256 minimumValidatorFeeUpdatePeriod = 1;

        pantosHubProxy.setMinimumValidatorFeeUpdatePeriod(
            minimumValidatorFeeUpdatePeriod
        );

        assertEq(
            pantosHubProxy.getMinimumValidatorFeeUpdatePeriod(),
            minimumValidatorFeeUpdatePeriod
        );
    }

    function test_setMinimumValidatorFeeUpdatePeriod_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.setMinimumValidatorFeeUpdatePeriod.selector,
            1
        );

        onlyOwnerTest(address(pantosHubProxy), calldata_);
    }

    function test_registerToken() external {
        initializePantosHub();
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, deployer());
        vm.expectEmit();
        emit IPantosRegistry.TokenRegistered(PANDAS_TOKEN_ADDRESS);

        pantosHubProxy.registerToken(PANDAS_TOKEN_ADDRESS);

        PantosTypes.TokenRecord memory tokenRecord = pantosHubProxy
            .getTokenRecord(PANDAS_TOKEN_ADDRESS);
        assertTrue(tokenRecord.active);
    }

    function test_registerToken_ByNonOwnerAndPaused() external {
        vm.prank(address(111));
        vm.expectRevert("LibDiamond: Must be contract owner");

        pantosHubProxy.registerToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_registerToken_WithToken0() external {
        initializePantosHub();
        vm.expectRevert("PantosHub: token must not be the zero account");

        pantosHubProxy.registerToken(ADDRESS_ZERO);
    }

    function test_registerToken_ByNonTokenOwner() external {
        initializePantosHub();
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, address(111));

        vm.expectRevert("PantosHub: caller is not the token owner");

        pantosHubProxy.registerToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_registerToken_WhenTokenAlreadyRegistered() external {
        registerToken();
        vm.expectRevert("PantosHub: token must not be active");

        pantosHubProxy.registerToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_unregisterToken() external {
        registerTokenAndExternalToken();
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, deployer());
        vm.expectEmit();
        emit IPantosRegistry.ExternalTokenUnregistered(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
        vm.expectEmit();
        emit IPantosRegistry.TokenUnregistered(PANDAS_TOKEN_ADDRESS);

        pantosHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);

        PantosTypes.TokenRecord memory tokenRecord = pantosHubProxy
            .getTokenRecord(PANDAS_TOKEN_ADDRESS);
        PantosTypes.ExternalTokenRecord
            memory externalTokenRecord = pantosHubProxy.getExternalTokenRecord(
                PANDAS_TOKEN_ADDRESS,
                uint256(otherBlockchain.blockchainId)
            );
        address[] memory tokens = pantosHubProxy.getTokens();
        assertEq(tokens.length, 1);
        assertEq(tokens[0], PANTOS_TOKEN_ADDRESS);
        assertFalse(tokenRecord.active);
        assertFalse(externalTokenRecord.active);
    }

    function test_unregisterToken_ByNonOwnerAndPaused() external {
        vm.prank(address(111));
        vm.expectRevert("LibDiamond: Must be contract owner");

        pantosHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_unregisterToken_WhenTokenNotRegistered() external {
        vm.expectRevert("PantosHub: token must be active");

        pantosHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_unregisterToken_WhenTokenAlreadyUnRegistered() external {
        registerToken();
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, deployer());
        pantosHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
        vm.expectRevert("PantosHub: token must be active");

        pantosHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_unregisterToken_ByNonTokenOwner() external {
        registerToken();
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, address(123));

        vm.expectRevert("PantosHub: caller is not the token owner");

        pantosHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_registerExternalToken() external {
        registerToken();

        pantosHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );

        PantosTypes.ExternalTokenRecord
            memory externalTokenRecord = pantosHubProxy.getExternalTokenRecord(
                PANDAS_TOKEN_ADDRESS,
                uint256(otherBlockchain.blockchainId)
            );
        assertTrue(externalTokenRecord.active);
        assertEq(
            externalTokenRecord.externalToken,
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_registerExternalToken_ByNonOwnerAndPaused() external {
        vm.prank(address(111));
        vm.expectRevert("LibDiamond: Must be contract owner");

        pantosHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_registerExternalToken_WithCurrentBlockchainId() external {
        initializePantosHub();
        vm.expectRevert(
            "PantosHub: blockchain must not be the current blockchain"
        );

        pantosHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(thisBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_registerExternalToken_WithInactiveBlockchainId() external {
        initializePantosHub();
        vm.expectRevert(
            "PantosHub: blockchain of external token must be active"
        );

        pantosHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(type(BlockchainId).max) + 1,
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_registerExternalToken_WithEmptyAddress() external {
        initializePantosHub();
        vm.expectRevert("PantosHub: external token address must not be empty");

        pantosHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            ""
        );
    }

    function test_registerExternalToken_WithInactiveToken() external {
        initializePantosHub();
        vm.expectRevert("PantosHub: token must be active");

        pantosHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_registerExternalToken_ByNonTokenOwner() external {
        registerToken();
        vm.mockCall(
            PANDAS_TOKEN_ADDRESS,
            abi.encodeWithSelector(PantosBaseToken.getOwner.selector),
            abi.encode(address(321))
        );
        vm.expectRevert("PantosHub: caller is not the token owner");

        pantosHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_registerExternalToken_WhenAlreadyRegistered() external {
        registerTokenAndExternalToken();
        vm.expectRevert("PantosHub: external token must not be active");

        pantosHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_unregisterExternalToken() external {
        registerTokenAndExternalToken();
        vm.expectEmit();
        emit IPantosRegistry.ExternalTokenUnregistered(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );

        pantosHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );

        PantosTypes.ExternalTokenRecord
            memory externalTokenRecord = pantosHubProxy.getExternalTokenRecord(
                PANDAS_TOKEN_ADDRESS,
                uint256(otherBlockchain.blockchainId)
            );
        assertFalse(externalTokenRecord.active);
    }

    function test_unregisterExternalToken_ByNonOwnerAndPaused() external {
        vm.prank(address(111));
        vm.expectRevert("LibDiamond: Must be contract owner");

        pantosHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
    }

    function test_unregisterExternalToken_WithInactiveToken() external {
        initializePantosHub();
        vm.prank(address(111));
        vm.expectRevert("PantosHub: token must be active");

        pantosHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
    }

    function test_unregisterExternalToken_ByNonTokenOwner() external {
        registerTokenAndExternalToken();
        vm.mockCall(
            PANDAS_TOKEN_ADDRESS,
            abi.encodeWithSelector(PantosBaseToken.getOwner.selector),
            abi.encode(address(321))
        );
        vm.expectRevert("PantosHub: caller is not the token owner");

        pantosHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
    }

    function test_unregisterExternalToken_WithInactiveExternalToken()
        external
    {
        registerToken();
        vm.expectRevert("PantosHub: external token must be active");

        pantosHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
    }

    function test_registerServiceNode() external {
        initializePantosHub();
        mockIerc20_transferFrom(
            PANTOS_TOKEN_ADDRESS,
            SERVICE_NODE_ADDRESS,
            address(pantosHubProxy),
            MINIMUM_SERVICE_NODE_DEPOSIT,
            true
        );
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectEmit();
        emit IPantosRegistry.ServiceNodeRegistered(SERVICE_NODE_ADDRESS);
        vm.expectCall(
            PANTOS_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                SERVICE_NODE_ADDRESS,
                address(pantosHubProxy),
                MINIMUM_SERVICE_NODE_DEPOSIT
            )
        );

        pantosHubProxy.registerServiceNode(
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );

        PantosTypes.ServiceNodeRecord memory serviceNodeRecord = pantosHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        address[] memory serviceNodes = pantosHubProxy.getServiceNodes();
        assertTrue(serviceNodeRecord.active);
        assertEq(serviceNodeRecord.url, SERVICE_NODE_URL);
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT);
        assertEq(
            serviceNodeRecord.withdrawalAddress,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
        assertEq(serviceNodeRecord.unregisterTime, 0);
        assertEq(serviceNodes.length, 1);
        assertEq(serviceNodes[0], SERVICE_NODE_ADDRESS);
    }

    function test_registerServiceNode_WhenPaused() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.registerServiceNode.selector,
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );

        whenNotPausedTest(address(pantosHubProxy), calldata_);
    }

    function test_registerServiceNode_ByUnauthorizedAddress() external {
        initializePantosHub();
        vm.prank(address(123));
        vm.expectRevert(
            "PantosHub: caller is not the service "
            "node or the withdrawal address"
        );

        pantosHubProxy.registerServiceNode(
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
    }

    function test_registerServiceNode_WithEmptyUrl() external {
        initializePantosHub();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("PantosHub: service node URL must not be empty");

        pantosHubProxy.registerServiceNode(
            SERVICE_NODE_ADDRESS,
            "",
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
    }

    function test_registerServiceNode_WithNotUniqueUrl() external {
        registerServiceNode();
        address newSERVICE_NODE_ADDRESS = address(123);
        vm.prank(newSERVICE_NODE_ADDRESS);
        vm.expectRevert("PantosHub: service node URL must be unique");

        pantosHubProxy.registerServiceNode(
            newSERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            newSERVICE_NODE_ADDRESS
        );
    }

    function test_registerServiceNode_WithNotEnoughDeposit() external {
        initializePantosHub();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert(
            "PantosHub: deposit must be >= minimum service node deposit"
        );

        pantosHubProxy.registerServiceNode(
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT - 1,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
    }

    function test_registerServiceNode_WhenServiceNodeAlreadyRegistered()
        external
    {
        registerServiceNode();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("PantosHub: service node already registered");

        pantosHubProxy.registerServiceNode(
            SERVICE_NODE_ADDRESS,
            string.concat(SERVICE_NODE_URL, "/new/path/"),
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
    }

    function test_registerServiceNode_WithDifferentUrlWhenNotWithdrawn()
        external
    {
        registerServiceNode();
        vm.prank(SERVICE_NODE_ADDRESS);
        pantosHubProxy.unregisterServiceNode(SERVICE_NODE_ADDRESS);
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert(
            "PantosHub: service node must withdraw its "
            "deposit or cancel the unregistration"
        );

        pantosHubProxy.registerServiceNode(
            SERVICE_NODE_ADDRESS,
            string.concat(SERVICE_NODE_URL, "extra"),
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
    }

    function test_registerServiceNode_WithSameUrlWhenNotWithdrawn() external {
        registerServiceNode();
        vm.prank(SERVICE_NODE_ADDRESS);
        pantosHubProxy.unregisterServiceNode(SERVICE_NODE_ADDRESS);
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("PantosHub: service node URL must be unique");

        pantosHubProxy.registerServiceNode(
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
    }

    function test_unregisterServiceNode() external {
        registerServiceNode();
        vm.expectEmit();
        emit IPantosRegistry.ServiceNodeUnregistered(SERVICE_NODE_ADDRESS);
        vm.prank(SERVICE_NODE_ADDRESS);

        pantosHubProxy.unregisterServiceNode(SERVICE_NODE_ADDRESS);

        PantosTypes.ServiceNodeRecord memory serviceNodeRecord = pantosHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        address[] memory serviceNodes = pantosHubProxy.getServiceNodes();
        assertFalse(serviceNodeRecord.active);
        assertEq(serviceNodeRecord.unregisterTime, BLOCK_TIMESTAMP);
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT);
        assertEq(serviceNodes.length, 0);
    }

    function test_unregisterServiceNode_WhenPaused() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.unregisterServiceNode.selector,
            SERVICE_NODE_ADDRESS
        );

        whenNotPausedTest(address(pantosHubProxy), calldata_);
    }

    function test_unregisterServiceNode_ByUnauthorizedAddress() external {
        initializePantosHub();
        vm.prank(address(123));
        vm.expectRevert(
            "PantosHub: caller is not the service "
            "node or the withdrawal address"
        );

        pantosHubProxy.unregisterServiceNode(SERVICE_NODE_ADDRESS);
    }

    function test_unregisterServiceNode_WhenItWasNeverRegistered() external {
        initializePantosHub();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("PantosHub: service node must be active");

        pantosHubProxy.unregisterServiceNode(SERVICE_NODE_ADDRESS);
    }

    function test_withdrawServiceNodeDeposit_ByWithdrawalAddress() external {
        registerServiceNode();
        unregisterServicenode();
        mockIerc20_transfer(
            PANTOS_TOKEN_ADDRESS,
            SERVICE_NODE_WITHDRAWAL_ADDRESS,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            true
        );
        vm.warp(BLOCK_TIMESTAMP + SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD);
        vm.prank(SERVICE_NODE_WITHDRAWAL_ADDRESS);
        vm.expectCall(
            PANTOS_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transfer.selector,
                SERVICE_NODE_WITHDRAWAL_ADDRESS,
                MINIMUM_SERVICE_NODE_DEPOSIT
            )
        );

        pantosHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);

        PantosTypes.ServiceNodeRecord memory serviceNodeRecord = pantosHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertEq(serviceNodeRecord.unregisterTime, 0);
        assertEq(serviceNodeRecord.deposit, 0);
    }

    function test_withdrawServiceNodeDeposit_ByServiceNode() external {
        registerServiceNode();
        unregisterServicenode();
        mockIerc20_transfer(
            PANTOS_TOKEN_ADDRESS,
            SERVICE_NODE_WITHDRAWAL_ADDRESS,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            true
        );
        vm.warp(BLOCK_TIMESTAMP + SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD);
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectCall(
            PANTOS_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transfer.selector,
                SERVICE_NODE_WITHDRAWAL_ADDRESS,
                MINIMUM_SERVICE_NODE_DEPOSIT
            )
        );

        pantosHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);

        PantosTypes.ServiceNodeRecord memory serviceNodeRecord = pantosHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertEq(serviceNodeRecord.unregisterTime, 0);
        assertEq(serviceNodeRecord.deposit, 0);
    }

    function test_withdrawServiceNodeDeposit_WhenAlreadyWithdrawn() external {
        registerServiceNode();
        unregisterServicenode();
        mockIerc20_transfer(
            PANTOS_TOKEN_ADDRESS,
            SERVICE_NODE_WITHDRAWAL_ADDRESS,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            true
        );
        vm.warp(BLOCK_TIMESTAMP + SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD);
        vm.prank(SERVICE_NODE_ADDRESS);
        pantosHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);
        vm.expectRevert("PantosHub: service node has no deposit to withdraw");

        pantosHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);
    }

    function test_withdrawServiceNodeDeposit_ByUnauthorizedParty() external {
        registerServiceNode();
        unregisterServicenode();
        vm.warp(BLOCK_TIMESTAMP + SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD);
        vm.prank(address(123));
        vm.expectRevert(
            "PantosHub: caller is not the service node or the "
            "withdrawal address"
        );

        pantosHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);
    }

    function test_withdrawServiceNodeDeposit_WhenUnbondingPeriodIsNotElapsed()
        external
    {
        registerServiceNode();
        unregisterServicenode();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("PantosHub: the unbonding period has not elapsed");

        pantosHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);
    }

    function test_cancelServiceNodeUnregistration_ByWithdrawalAddress()
        external
    {
        registerServiceNode();
        unregisterServicenode();
        vm.prank(SERVICE_NODE_WITHDRAWAL_ADDRESS);

        pantosHubProxy.cancelServiceNodeUnregistration(SERVICE_NODE_ADDRESS);

        PantosTypes.ServiceNodeRecord memory serviceNodeRecord = pantosHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        address[] memory serviceNodes = pantosHubProxy.getServiceNodes();
        assertTrue(serviceNodeRecord.active);
        assertEq(serviceNodeRecord.url, SERVICE_NODE_URL);
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT);
        assertEq(
            serviceNodeRecord.withdrawalAddress,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
        assertEq(serviceNodeRecord.unregisterTime, 0);
        assertEq(serviceNodes.length, 1);
        assertEq(serviceNodes[0], SERVICE_NODE_ADDRESS);
    }

    function test_cancelServiceNodeUnregistration_ByServiceNode() external {
        registerServiceNode();
        unregisterServicenode();
        vm.prank(SERVICE_NODE_ADDRESS);

        pantosHubProxy.cancelServiceNodeUnregistration(SERVICE_NODE_ADDRESS);

        PantosTypes.ServiceNodeRecord memory serviceNodeRecord = pantosHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        address[] memory serviceNodes = pantosHubProxy.getServiceNodes();
        assertTrue(serviceNodeRecord.active);
        assertEq(serviceNodeRecord.url, SERVICE_NODE_URL);
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT);
        assertEq(
            serviceNodeRecord.withdrawalAddress,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
        assertEq(serviceNodeRecord.unregisterTime, 0);
        assertEq(serviceNodes.length, 1);
        assertEq(serviceNodes[0], SERVICE_NODE_ADDRESS);
    }

    function test_cancelServiceNodeUnregistration_WhenServiceNodeNotUnbonding()
        external
    {
        registerServiceNode();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert(
            "PantosHub: service node is not in the unbonding period"
        );

        pantosHubProxy.cancelServiceNodeUnregistration(SERVICE_NODE_ADDRESS);
    }

    function test_cancelServiceNodeUnregistration_ByUnauthorizedParty()
        external
    {
        registerServiceNode();
        unregisterServicenode();
        vm.expectRevert(
            "PantosHub: caller is not the service node or the "
            "withdrawal address"
        );

        pantosHubProxy.cancelServiceNodeUnregistration(SERVICE_NODE_ADDRESS);
    }

    function test_increaseServiceNodeDeposit_ByWithdrawalAddress() external {
        registerServiceNode();
        mockIerc20_transferFrom(
            PANTOS_TOKEN_ADDRESS,
            SERVICE_NODE_WITHDRAWAL_ADDRESS,
            address(pantosHubProxy),
            1,
            true
        );
        vm.prank(SERVICE_NODE_WITHDRAWAL_ADDRESS);
        vm.expectCall(
            PANTOS_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                SERVICE_NODE_WITHDRAWAL_ADDRESS,
                address(pantosHubProxy),
                1
            )
        );

        pantosHubProxy.increaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);

        PantosTypes.ServiceNodeRecord memory serviceNodeRecord = pantosHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT + 1);
    }

    function test_increaseServiceNodeDeposit_ByServiceNode() external {
        registerServiceNode();
        mockIerc20_transferFrom(
            PANTOS_TOKEN_ADDRESS,
            SERVICE_NODE_ADDRESS,
            address(pantosHubProxy),
            1,
            true
        );
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectCall(
            PANTOS_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                SERVICE_NODE_ADDRESS,
                address(pantosHubProxy),
                1
            )
        );

        pantosHubProxy.increaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);

        PantosTypes.ServiceNodeRecord memory serviceNodeRecord = pantosHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT + 1);
    }

    function test_increaseServiceNodeDeposit_ByUnauthorizedParty() external {
        registerServiceNode();
        vm.expectRevert(
            "PantosHub: caller is not the service node or the "
            "withdrawal address"
        );

        pantosHubProxy.increaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);
    }

    function test_increaseServiceNodeDeposit_WhenServiceNodeNotActive()
        external
    {
        registerServiceNode();
        unregisterServicenode();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("PantosHub: service node must be active");

        pantosHubProxy.increaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);
    }

    function test_increaseServiceNodeDeposit_WithDeposit0() external {
        registerServiceNode();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert(
            "PantosHub: additional deposit must be greater than 0"
        );

        pantosHubProxy.increaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 0);
    }

    function test_increaseServiceNodeDeposit_WithNotEnoughDeposit() external {
        registerServiceNode();
        pantosHubProxy.pause();
        pantosHubProxy.setMinimumServiceNodeDeposit(
            MINIMUM_SERVICE_NODE_DEPOSIT + 2
        );
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert(
            "PantosHub: new deposit must be at least the minimum "
            "service node deposit"
        );

        pantosHubProxy.increaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);
    }

    function test_decreaseServiceNodeDeposit_ByWithdrawalAddress() external {
        registerServiceNode();
        mockIerc20_transfer(
            PANTOS_TOKEN_ADDRESS,
            SERVICE_NODE_WITHDRAWAL_ADDRESS,
            1,
            true
        );
        pantosHubProxy.pause();
        pantosHubProxy.setMinimumServiceNodeDeposit(
            MINIMUM_SERVICE_NODE_DEPOSIT - 1
        );
        vm.prank(SERVICE_NODE_WITHDRAWAL_ADDRESS);
        vm.expectCall(
            PANTOS_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transfer.selector,
                SERVICE_NODE_WITHDRAWAL_ADDRESS,
                1
            )
        );

        pantosHubProxy.decreaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);

        PantosTypes.ServiceNodeRecord memory serviceNodeRecord = pantosHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT - 1);
    }

    function test_decreaseServiceNodeDeposit_ByServiceNode() external {
        registerServiceNode();
        mockIerc20_transfer(
            PANTOS_TOKEN_ADDRESS,
            SERVICE_NODE_WITHDRAWAL_ADDRESS,
            1,
            true
        );
        pantosHubProxy.pause();
        pantosHubProxy.setMinimumServiceNodeDeposit(
            MINIMUM_SERVICE_NODE_DEPOSIT - 1
        );
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectCall(
            PANTOS_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transfer.selector,
                SERVICE_NODE_WITHDRAWAL_ADDRESS,
                1
            )
        );

        pantosHubProxy.decreaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);

        PantosTypes.ServiceNodeRecord memory serviceNodeRecord = pantosHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT - 1);
    }

    function test_decreaseServiceNodeDeposit_ByUnauthorizedParty() external {
        registerServiceNode();
        vm.expectRevert(
            "PantosHub: caller is not the service node or the "
            "withdrawal address"
        );

        pantosHubProxy.decreaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);
    }

    function test_decreaseServiceNodeDeposit_WhenServiceNodeNotActive()
        external
    {
        registerServiceNode();
        unregisterServicenode();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("PantosHub: service node must be active");

        pantosHubProxy.decreaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);
    }

    function test_decreaseServiceNodeDeposit_WithDeposit0() external {
        registerServiceNode();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("PantosHub: reduced deposit must be greater than 0");

        pantosHubProxy.decreaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 0);
    }

    function test_decreaseServiceNodeDeposit_WithNotEnoughDeposit() external {
        registerServiceNode();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert(
            "PantosHub: new deposit must be at least the minimum "
            "service node deposit"
        );

        pantosHubProxy.decreaseServiceNodeDeposit(SERVICE_NODE_ADDRESS, 1);
    }

    function test_updateServiceNodeUrl() external {
        string memory newSERVICE_NODE_URL = "new service node url";
        registerServiceNode();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectEmit();
        emit IPantosRegistry.ServiceNodeUrlUpdated(SERVICE_NODE_ADDRESS);

        pantosHubProxy.updateServiceNodeUrl(newSERVICE_NODE_URL);

        PantosTypes.ServiceNodeRecord memory serviceNodeRecord = pantosHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertEq(serviceNodeRecord.url, newSERVICE_NODE_URL);
    }

    function test_updateServiceNodeUrl_WhenPaused() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            pantosHubProxy.updateServiceNodeUrl.selector,
            "new service node url"
        );

        whenNotPausedTest(address(pantosHubProxy), calldata_);
    }

    function test_updateServiceNodeUrlL_WithEmptyUrl() external {
        registerServiceNode();
        vm.expectRevert("PantosHub: service node URL must not be empty");

        pantosHubProxy.updateServiceNodeUrl("");
    }

    function test_updateServiceNodeUrl_WithNonUniqueUrl() external {
        registerServiceNode();
        vm.expectRevert("PantosHub: service node URL must be unique");

        pantosHubProxy.updateServiceNodeUrl(SERVICE_NODE_URL);
    }

    function test_updateServiceNodeUrl_WithDifferentUrlWhenNotActive()
        external
    {
        registerServiceNode();
        unregisterServicenode();
        vm.expectRevert("PantosHub: service node must be active");

        pantosHubProxy.updateServiceNodeUrl(
            string.concat(SERVICE_NODE_URL, "extra")
        );
    }

    function test_updateServiceNodeUrl_WithSameUrlWhenNotActive() external {
        registerServiceNode();
        unregisterServicenode();
        vm.expectRevert("PantosHub: service node URL must be unique");

        pantosHubProxy.updateServiceNodeUrl(SERVICE_NODE_URL);
    }

    function test_transfer() external {
        registerToken();
        registerServiceNode();
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        mockPantosForwarder_verifyAndForwardTransfer(
            PANTOS_FORWARDER_ADDRESS,
            transferRequest(),
            ""
        );
        vm.expectEmit();
        emit IPantosTransfer.Transfer(
            NEXT_TRANSFER_ID,
            transferSender,
            TRANSFER_RECIPIENT,
            PANDAS_TOKEN_ADDRESS,
            TRANSFER_AMOUNT,
            TRANSFER_FEE,
            SERVICE_NODE_ADDRESS
        );
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectCall(
            PANTOS_FORWARDER_ADDRESS,
            abi.encodeWithSelector(
                IPantosForwarder.verifyAndForwardTransfer.selector,
                transferRequest(),
                ""
            )
        );

        uint256 transferId = pantosHubProxy.transfer(transferRequest(), "");
        assertEq(transferId, NEXT_TRANSFER_ID);
        assertEq(pantosHubProxy.getNextTransferId(), NEXT_TRANSFER_ID + 1);
    }

    function test_transfer_ByUnauthorizedParty() external {
        initializePantosHub();
        vm.expectRevert("PantosHub: caller must be the service node");

        pantosHubProxy.transfer(transferRequest(), "");
    }

    function test_transferFrom_WithOldFactors() external {
        registerTokenAndExternalToken();
        registerServiceNode();
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        mockPantosForwarder_verifyAndForwardTransferFrom(
            PANTOS_FORWARDER_ADDRESS,
            transferFromRequest(),
            ""
        );
        vm.expectEmit();
        emit IPantosTransfer.TransferFrom(
            NEXT_TRANSFER_ID,
            uint256(otherBlockchain.blockchainId),
            transferSender,
            vm.toString(TRANSFER_RECIPIENT),
            PANDAS_TOKEN_ADDRESS,
            EXTERNAL_PANDAS_TOKEN_ADDRESS,
            TRANSFER_AMOUNT,
            TRANSFER_FEE,
            SERVICE_NODE_ADDRESS
        );
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectCall(
            PANTOS_FORWARDER_ADDRESS,
            abi.encodeWithSelector(
                IPantosForwarder.verifyAndForwardTransferFrom.selector,
                0,
                0,
                transferFromRequest(),
                ""
            )
        );

        uint256 transferId = pantosHubProxy.transferFrom(
            transferFromRequest(),
            ""
        );
        assertEq(transferId, NEXT_TRANSFER_ID);
        assertEq(pantosHubProxy.getNextTransferId(), NEXT_TRANSFER_ID + 1);
    }

    function test_transferFrom_WithNewFactors() external {
        registerTokenAndExternalToken();
        registerServiceNode();
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        mockPantosForwarder_verifyAndForwardTransferFrom(
            PANTOS_FORWARDER_ADDRESS,
            transferFromRequest(),
            ""
        );
        vm.expectEmit();
        emit IPantosTransfer.TransferFrom(
            NEXT_TRANSFER_ID,
            uint256(otherBlockchain.blockchainId),
            transferSender,
            vm.toString(TRANSFER_RECIPIENT),
            PANDAS_TOKEN_ADDRESS,
            EXTERNAL_PANDAS_TOKEN_ADDRESS,
            TRANSFER_AMOUNT,
            TRANSFER_FEE,
            SERVICE_NODE_ADDRESS
        );
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.warp(FEE_FACTOR_VALID_FROM);
        vm.expectCall(
            PANTOS_FORWARDER_ADDRESS,
            abi.encodeWithSelector(
                IPantosForwarder.verifyAndForwardTransferFrom.selector,
                thisBlockchain.feeFactor,
                otherBlockchain.feeFactor,
                transferFromRequest(),
                ""
            )
        );

        uint256 transferId = pantosHubProxy.transferFrom(
            transferFromRequest(),
            ""
        );
        assertEq(transferId, NEXT_TRANSFER_ID);
        assertEq(pantosHubProxy.getNextTransferId(), NEXT_TRANSFER_ID + 1);
    }

    function test_transferFrom_ByUnauthorizedParty() external {
        initializePantosHub();
        vm.expectRevert("PantosHub: caller must be the service node");

        pantosHubProxy.transferFrom(transferFromRequest(), "");
    }

    function test_transferTo_WhenSourceAndDestinatioBlockchainsDiffer()
        external
    {
        registerTokenAndExternalToken();
        registerServiceNode();
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        mockPantosForwarder_verifyAndForwardTransferTo(
            PANTOS_FORWARDER_ADDRESS,
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );
        vm.expectEmit();
        emit IPantosTransfer.TransferTo(
            uint256(otherBlockchain.blockchainId),
            OTHER_BLOCKCHAIN_TRANSFER_ID,
            OTHER_BLOCKCHAIN_TRANSACTION_ID,
            NEXT_TRANSFER_ID,
            vm.toString(transferSender),
            TRANSFER_RECIPIENT,
            EXTERNAL_PANDAS_TOKEN_ADDRESS,
            PANDAS_TOKEN_ADDRESS,
            TRANSFER_AMOUNT,
            TRANSFER_NONCE,
            new address[](0),
            new bytes[](0)
        );
        vm.prank(validatorAddress);
        vm.expectCall(
            PANTOS_FORWARDER_ADDRESS,
            abi.encodeWithSelector(
                IPantosForwarder.verifyAndForwardTransferTo.selector,
                transferToRequest(),
                new address[](0),
                new bytes[](0)
            )
        );

        uint256 transferId = pantosHubProxy.transferTo(
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );
        assertEq(transferId, NEXT_TRANSFER_ID);
        assertEq(pantosHubProxy.getNextTransferId(), NEXT_TRANSFER_ID + 1);
    }

    function test_transferTo_WhenSourceAndDestinationBlockchainAreEqual()
        external
    {
        registerTokenAndExternalToken();
        registerServiceNode();
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        mockPantosForwarder_verifyAndForwardTransferTo(
            PANTOS_FORWARDER_ADDRESS,
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );
        PantosTypes.TransferToRequest
            memory transferToRequest_ = transferToRequest();
        transferToRequest_.sourceBlockchainId = uint256(
            thisBlockchain.blockchainId
        );
        vm.expectEmit();
        emit IPantosTransfer.TransferTo(
            uint256(thisBlockchain.blockchainId),
            OTHER_BLOCKCHAIN_TRANSFER_ID,
            OTHER_BLOCKCHAIN_TRANSACTION_ID,
            NEXT_TRANSFER_ID,
            vm.toString(transferSender),
            TRANSFER_RECIPIENT,
            EXTERNAL_PANDAS_TOKEN_ADDRESS,
            PANDAS_TOKEN_ADDRESS,
            TRANSFER_AMOUNT,
            TRANSFER_NONCE,
            new address[](0),
            new bytes[](0)
        );
        vm.prank(validatorAddress);
        vm.expectCall(
            PANTOS_FORWARDER_ADDRESS,
            abi.encodeWithSelector(
                IPantosForwarder.verifyAndForwardTransferTo.selector,
                transferToRequest_,
                new address[](0),
                new bytes[](0)
            )
        );

        uint256 transferId = pantosHubProxy.transferTo(
            transferToRequest_,
            new address[](0),
            new bytes[](0)
        );
        assertEq(transferId, NEXT_TRANSFER_ID);
        assertEq(pantosHubProxy.getNextTransferId(), NEXT_TRANSFER_ID + 1);
    }

    function test_transferTo_ByUnauthorizedParty() external {
        initializePantosHub();
        vm.expectRevert("PantosHub: caller is not the primary validator node");

        pantosHubProxy.transferTo(
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );
    }

    function test_isServiceNodeInTheUnbondingPeriod_WhenInUnbondingPeriod()
        external
    {
        registerServiceNode();
        unregisterServicenode();

        assertTrue(
            pantosHubProxy.isServiceNodeInTheUnbondingPeriod(
                SERVICE_NODE_ADDRESS
            )
        );
    }

    function test_isServiceNodeInTheUnbondingPeriod_WhenAlreadyWithdrawn()
        external
    {
        registerServiceNode();
        unregisterServicenode();
        mockIerc20_transfer(
            PANTOS_TOKEN_ADDRESS,
            SERVICE_NODE_WITHDRAWAL_ADDRESS,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            true
        );
        vm.warp(BLOCK_TIMESTAMP + SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD);
        vm.prank(SERVICE_NODE_WITHDRAWAL_ADDRESS);
        pantosHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);

        assertFalse(
            pantosHubProxy.isServiceNodeInTheUnbondingPeriod(
                SERVICE_NODE_ADDRESS
            )
        );
    }

    function test_isServiceNodeInTheUnbondingPeriod_WhenNeverRegistered()
        external
    {
        assertFalse(
            pantosHubProxy.isServiceNodeInTheUnbondingPeriod(
                SERVICE_NODE_ADDRESS
            )
        );
    }

    function test_isValidValidatorNodeNonce_WhenValid() external {
        initializePantosHub();
        mockPantosForwarder_isValidValidatorNodeNonce(
            PANTOS_FORWARDER_ADDRESS,
            0,
            true
        );

        assertTrue(pantosHubProxy.isValidValidatorNodeNonce(0));
    }

    function test_isValidValidatorNodeNonce_WhenNotValid() external {
        initializePantosHub();
        vm.mockCall(
            PANTOS_FORWARDER_ADDRESS,
            abi.encodeWithSelector(
                PantosForwarder.isValidValidatorNodeNonce.selector
            ),
            abi.encode(false)
        );

        assertFalse(pantosHubProxy.isValidValidatorNodeNonce(0));
    }

    function test_isValidSenderNodeNonce_WhenValid() external {
        initializePantosHub();
        mockPantosForwarder_isValidSenderNonce(
            PANTOS_FORWARDER_ADDRESS,
            transferSender,
            0,
            true
        );

        assertTrue(pantosHubProxy.isValidSenderNonce(transferSender, 0));
    }

    function test_isValidSenderNodeNonce_WhenNotValid() external {
        initializePantosHub();
        vm.mockCall(
            PANTOS_FORWARDER_ADDRESS,
            abi.encodeWithSelector(
                PantosForwarder.isValidSenderNonce.selector
            ),
            abi.encode(false)
        );

        assertFalse(pantosHubProxy.isValidSenderNonce(transferSender, 0));
    }

    function test_verifyTransfer() external {
        registerToken();
        registerServiceNode();
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        mockIerc20_balanceOf(
            PANDAS_TOKEN_ADDRESS,
            transferSender,
            TRANSFER_AMOUNT
        );
        mockIerc20_balanceOf(
            PANTOS_TOKEN_ADDRESS,
            transferSender,
            TRANSFER_FEE
        );
        mockPantosForwarder_verifyTransfer(
            PANTOS_FORWARDER_ADDRESS,
            transferRequest(),
            ""
        );

        pantosHubProxy.verifyTransfer(transferRequest(), "");
    }

    function test_verifyTransfer_WhenTokenNotRegistered() external {
        vm.expectRevert("PantosHub: token must be registered");

        pantosHubProxy.verifyTransfer(transferRequest(), "");
    }

    function test_verifyTransfer_WhenTokenHasNotSetTheRightForwarder()
        external
    {
        registerToken();
        mockPandasToken_getPantosForwarder(PANDAS_TOKEN_ADDRESS, address(123));
        vm.expectRevert(
            "PantosHub: Forwarder of Hub and transferred token must match"
        );

        pantosHubProxy.verifyTransfer(transferRequest(), "");
    }

    function test_verifyTransfer_WhenServiceNodeIsNotRegistered() external {
        registerToken();
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        vm.expectRevert("PantosHub: service node must be registered");

        pantosHubProxy.verifyTransfer(transferRequest(), "");
    }

    function test_verifyTransfer_WhenServiceNodeHasNotEnoughDeposit()
        external
    {
        registerToken();
        registerServiceNode();
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        pantosHubProxy.pause();
        pantosHubProxy.setMinimumServiceNodeDeposit(
            MINIMUM_SERVICE_NODE_DEPOSIT + 1
        );
        vm.expectRevert("PantosHub: service node must have enough deposit");

        pantosHubProxy.verifyTransfer(transferRequest(), "");
    }

    function test_verifyTransfer_WithPAN_WhenInsufficientPANbalance()
        external
    {
        registerToken();
        registerServiceNode();
        PantosTypes.TransferRequest
            memory transferRequest_ = transferRequest();
        transferRequest_.token = PANTOS_TOKEN_ADDRESS;
        mockPandasToken_getPantosForwarder(
            PANTOS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        mockPantosForwarder_verifyTransfer(
            PANTOS_FORWARDER_ADDRESS,
            transferRequest(),
            ""
        );
        mockIerc20_balanceOf(
            PANTOS_TOKEN_ADDRESS,
            transferSender,
            TRANSFER_AMOUNT + TRANSFER_FEE - 1
        );
        vm.expectRevert("PantosHub: insufficient balance of sender");

        pantosHubProxy.verifyTransfer(transferRequest_, "");
    }

    function test_verifyTransfer_WithPANDAS_WhenInsufficientPANbalance()
        external
    {
        registerToken();
        registerServiceNode();
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        mockPantosForwarder_verifyTransfer(
            PANTOS_FORWARDER_ADDRESS,
            transferRequest(),
            ""
        );
        mockIerc20_balanceOf(
            PANDAS_TOKEN_ADDRESS,
            transferSender,
            TRANSFER_AMOUNT
        );
        mockIerc20_balanceOf(
            PANTOS_TOKEN_ADDRESS,
            transferSender,
            TRANSFER_FEE - 1
        );
        vm.expectRevert(
            "PantosHub: insufficient balance of sender for fee payment"
        );

        pantosHubProxy.verifyTransfer(transferRequest(), "");
    }

    function test_verifyTransfer_WithPANDAS_WhenInsufficientPANDASbalance()
        external
    {
        registerToken();
        registerServiceNode();
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        mockPantosForwarder_verifyTransfer(
            PANTOS_FORWARDER_ADDRESS,
            transferRequest(),
            ""
        );
        mockIerc20_balanceOf(
            PANDAS_TOKEN_ADDRESS,
            transferSender,
            TRANSFER_AMOUNT - 1
        );
        vm.expectRevert("PantosHub: insufficient balance of sender");

        pantosHubProxy.verifyTransfer(transferRequest(), "");
    }

    function test_verifyTransferFrom() external {
        registerTokenAndExternalToken();
        registerServiceNode();
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        mockIerc20_balanceOf(
            PANDAS_TOKEN_ADDRESS,
            transferSender,
            TRANSFER_AMOUNT
        );
        mockIerc20_balanceOf(
            PANTOS_TOKEN_ADDRESS,
            transferSender,
            TRANSFER_FEE
        );
        mockPantosForwarder_verifyTransferFrom(
            PANTOS_FORWARDER_ADDRESS,
            transferFromRequest(),
            ""
        );

        pantosHubProxy.verifyTransferFrom(transferFromRequest(), "");
    }

    function test_verifyTransferFrom_WithSameSourceAndDestinationBlockchain()
        external
    {
        registerTokenAndExternalToken();
        registerServiceNode();
        PantosTypes.TransferFromRequest
            memory transferFromRequest_ = transferFromRequest();
        transferFromRequest_.destinationBlockchainId = uint256(
            thisBlockchain.blockchainId
        );
        vm.expectRevert(
            "PantosHub: source and destination blockchains must not be equal"
        );

        pantosHubProxy.verifyTransferFrom(transferFromRequest_, "");
    }

    function test_verifyTransferFrom_WithInactiveDestinationBlockchain()
        external
    {
        registerTokenAndExternalToken();
        registerServiceNode();
        pantosHubProxy.unregisterBlockchain(
            uint256(otherBlockchain.blockchainId)
        );
        vm.expectRevert("PantosHub: blockchain must be active");

        pantosHubProxy.verifyTransferFrom(transferFromRequest(), "");
    }

    function test_verifyTransferFrom_WithNotRegisteredExternalToken()
        external
    {
        registerToken();
        registerServiceNode();
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        vm.expectRevert("PantosHub: external token must be registered");

        pantosHubProxy.verifyTransferFrom(transferFromRequest(), "");
    }

    function test_verifyTransferFrom_WithUnmatchingExternalToken() external {
        registerTokenAndExternalToken();
        registerServiceNode();
        PantosTypes.TransferFromRequest
            memory transferFromRequest_ = transferFromRequest();
        transferFromRequest_.destinationToken = "123";
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        vm.expectRevert("PantosHub: incorrect external token");

        pantosHubProxy.verifyTransferFrom(transferFromRequest_, "");
    }

    function test_verifyTransferTo_WhenSourceAndDestinatioBlockchainsDiffer()
        external
    {
        registerTokenAndExternalToken();
        registerServiceNode();
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        mockPantosForwarder_verifyTransferTo(
            PANTOS_FORWARDER_ADDRESS,
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );

        pantosHubProxy.verifyTransferTo(
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );
    }

    function test_verifyTransferTo_WhenSourceAndDestinationBlockchainAreEqual()
        external
    {
        registerTokenAndExternalToken();
        registerServiceNode();
        PantosTypes.TransferToRequest
            memory transferToRequest_ = transferToRequest();
        transferToRequest_.sourceBlockchainId = uint256(
            thisBlockchain.blockchainId
        );
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        mockPantosForwarder_verifyTransferTo(
            PANTOS_FORWARDER_ADDRESS,
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );

        pantosHubProxy.verifyTransferTo(
            transferToRequest_,
            new address[](0),
            new bytes[](0)
        );
    }

    function test_verifyTransferTo_WhenSourceTransferIdAlreadyUsed() external {
        registerTokenAndExternalToken();
        registerServiceNode();
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        mockPantosForwarder_verifyTransferTo(
            PANTOS_FORWARDER_ADDRESS,
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );
        vm.prank(validatorAddress);
        pantosHubProxy.transferTo(
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );
        vm.expectRevert("PantosHub: source transfer ID already used");

        pantosHubProxy.verifyTransferTo(
            transferToRequest(),
            new address[](0),
            new bytes[](0)
        );
    }

    function test_getPantosForwarder() external {
        initializePantosHub();

        assertEq(
            PANTOS_FORWARDER_ADDRESS,
            pantosHubProxy.getPantosForwarder()
        );
    }

    function test_getPantosToken() external {
        initializePantosHub();

        assertEq(PANTOS_TOKEN_ADDRESS, pantosHubProxy.getPantosToken());
    }

    function test_getPrimaryValidatorNode() external {
        initializePantosHub();

        assertEq(validatorAddress, pantosHubProxy.getPrimaryValidatorNode());
    }

    function test_getNumberBlockchains() external {
        assertEq(
            uint256(type(BlockchainId).max),
            pantosHubProxy.getNumberBlockchains()
        );
    }

    function test_getNumberActiveBlockchains() external {
        assertEq(
            uint256(type(BlockchainId).max),
            pantosHubProxy.getNumberActiveBlockchains()
        );
    }

    function test_getCurrentBlockchainId() external {
        assertEq(
            uint256(thisBlockchain.blockchainId),
            pantosHubProxy.getCurrentBlockchainId()
        );
    }

    function test_getBlockchainRecord() external {
        PantosTypes.BlockchainRecord
            memory thisBlockchainRecord = pantosHubProxy.getBlockchainRecord(
                uint256(thisBlockchain.blockchainId)
            );

        assertEq(thisBlockchainRecord.name, thisBlockchain.name);
        assertEq(thisBlockchainRecord.active, true);
    }

    function test_getMinimumServiceNodeDeposit() external {
        assertEq(
            MINIMUM_SERVICE_NODE_DEPOSIT,
            pantosHubProxy.getMinimumServiceNodeDeposit()
        );
    }

    function test_getUnbondingPeriodServiceNodeDeposit() external {
        assertEq(
            SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD,
            pantosHubProxy.getUnbondingPeriodServiceNodeDeposit()
        );
    }

    function test_getTokens_WhenOnlyPantosTokenRegistered() external {
        initializePantosHub();

        address[] memory tokens = pantosHubProxy.getTokens();

        assertEq(tokens.length, 1);
        assertEq(tokens[0], PANTOS_TOKEN_ADDRESS);
    }

    function test_getTokens_WhenPandasTokenRegistered() external {
        registerToken();

        address[] memory tokens = pantosHubProxy.getTokens();

        assertEq(tokens.length, 2);
        assertEq(tokens[0], PANTOS_TOKEN_ADDRESS);
        assertEq(tokens[1], PANDAS_TOKEN_ADDRESS);
    }

    function test_getTokenRecord_WhenTokenRegistered() external {
        registerToken();

        PantosTypes.TokenRecord memory tokenRecord = pantosHubProxy
            .getTokenRecord(PANDAS_TOKEN_ADDRESS);

        assertTrue(tokenRecord.active);
    }

    function test_getTokenRecord_WhenTokenNotRegistered() external {
        PantosTypes.TokenRecord memory tokenRecord = pantosHubProxy
            .getTokenRecord(address(123));

        assertFalse(tokenRecord.active);
    }

    function test_getExternalTokenRecord_WhenExternalTokenRegistered()
        external
    {
        registerTokenAndExternalToken();

        PantosTypes.ExternalTokenRecord
            memory externalTokenRecord = pantosHubProxy.getExternalTokenRecord(
                PANDAS_TOKEN_ADDRESS,
                uint256(otherBlockchain.blockchainId)
            );

        assertTrue(externalTokenRecord.active);
        assertEq(
            externalTokenRecord.externalToken,
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_getExternalTokenRecord_WhenExternalTokenNotRegistered()
        external
    {
        PantosTypes.ExternalTokenRecord
            memory externalTokenRecord = pantosHubProxy.getExternalTokenRecord(
                address(123),
                uint256(otherBlockchain.blockchainId)
            );

        assertFalse(externalTokenRecord.active);
        assertEq(externalTokenRecord.externalToken, "");
    }

    function test_getServiceNodes__WhenServiceNodeRegistered() external {
        registerServiceNode();

        address[] memory serviceNodes = pantosHubProxy.getServiceNodes();

        assertEq(serviceNodes.length, 1);
        assertEq(serviceNodes[0], SERVICE_NODE_ADDRESS);
    }

    function test_getServiceNodes__WhenServiceNodeNotRegistered() external {
        address[] memory serviceNodes = pantosHubProxy.getServiceNodes();

        assertEq(serviceNodes.length, 0);
    }

    function test_getServiceNodeRecord_WhenServiceNodeRegistered() external {
        registerServiceNode();

        PantosTypes.ServiceNodeRecord memory serviceNodeRecord = pantosHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);

        assertTrue(serviceNodeRecord.active);
        assertEq(serviceNodeRecord.url, SERVICE_NODE_URL);
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT);
        assertEq(
            serviceNodeRecord.withdrawalAddress,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
        assertEq(serviceNodeRecord.unregisterTime, 0);
    }

    function test_getServiceNodeRecord_WhenServiceNodeNotRegistered()
        external
    {
        PantosTypes.ServiceNodeRecord memory serviceNodeRecord = pantosHubProxy
            .getServiceNodeRecord(address(123));

        assertFalse(serviceNodeRecord.active);
        assertEq(serviceNodeRecord.url, "");
        assertEq(serviceNodeRecord.deposit, 0);
        assertEq(serviceNodeRecord.withdrawalAddress, ADDRESS_ZERO);
        assertEq(serviceNodeRecord.unregisterTime, 0);
    }

    function test_getNextTransferId() external {
        assertEq(pantosHubProxy.getNextTransferId(), 0);
    }

    function test_getValidatorFeeRecord() external {
        PantosTypes.ValidatorFeeRecord
            memory thisBlockchainValidatorFeeRecord = pantosHubProxy
                .getValidatorFeeRecord(uint256(thisBlockchain.blockchainId));

        assertEq(
            thisBlockchainValidatorFeeRecord.newFactor,
            thisBlockchain.feeFactor
        );
        assertEq(thisBlockchainValidatorFeeRecord.oldFactor, 0);
        assertEq(
            thisBlockchainValidatorFeeRecord.validFrom,
            FEE_FACTOR_VALID_FROM
        );
    }

    function test_getMinimumValidatorFeeUpdatePeriod_WhenSet() external {
        pantosHubProxy.setMinimumValidatorFeeUpdatePeriod(1);

        assertEq(pantosHubProxy.getMinimumValidatorFeeUpdatePeriod(), 1);
    }

    function test_getMinimumValidatorFeeUpdatePeriod_WhenNotSet() external {
        assertEq(pantosHubProxy.getMinimumValidatorFeeUpdatePeriod(), 0);
    }

    function test_owner() external {
        assertEq(pantosHubProxy.owner(), deployer());
    }

    function test_owner_AfterPantosHubInit() external {
        initializePantosHub();

        assertEq(pantosHubProxy.owner(), deployer());
    }

    function test_transferOwnership() external {
        address newOwner = address(111);
        vm.expectEmit(address(pantosHubProxy));
        emit IERC173.OwnershipTransferred(deployer(), newOwner);

        pantosHubProxy.transferOwnership(newOwner);

        assertEq(pantosHubProxy.owner(), newOwner);
    }

    function test_transferOwnership_AfterPantosHubInit() external {
        initializePantosHub();
        address newOwner = address(111);
        vm.expectEmit(address(pantosHubProxy));
        emit IERC173.OwnershipTransferred(deployer(), newOwner);

        pantosHubProxy.transferOwnership(newOwner);

        assertEq(pantosHubProxy.owner(), newOwner);
    }

    function test_transferOwnership_RenounceOwnership() external {
        vm.expectEmit(address(pantosHubProxy));
        emit IERC173.OwnershipTransferred(deployer(), address(0));

        pantosHubProxy.transferOwnership(address(0));

        assertEq(pantosHubProxy.owner(), address(0));
    }

    function test_transferOwnership_ByNonOwner() external {
        address newOwner = address(111);
        vm.startPrank(address(123));
        vm.expectRevert("LibDiamond: Must be contract owner");
        pantosHubProxy.transferOwnership(newOwner);

        assertEq(pantosHubProxy.owner(), deployer());
    }

    function test_transferOwnership_AfterReplaceFacets() external {
        reDeployRegistryAndTransferFacetsAndDiamondCut();

        address newOwner = address(111);
        vm.expectEmit(address(pantosHubProxy));
        emit IERC173.OwnershipTransferred(deployer(), newOwner);

        pantosHubProxy.transferOwnership(newOwner);

        assertEq(pantosHubProxy.owner(), newOwner);
    }

    function test_transferOwnership_ByNonOwnerAfterReplaceFacets() external {
        reDeployRegistryAndTransferFacetsAndDiamondCut();
        address newOwner = address(111);
        vm.startPrank(address(123));
        vm.expectRevert("LibDiamond: Must be contract owner");
        pantosHubProxy.transferOwnership(newOwner);

        assertEq(pantosHubProxy.owner(), deployer());
    }

    function onlyOwnerTest(
        address callee,
        bytes memory calldata_
    ) public override {
        string memory revertMessage = "LibDiamond: Must be contract owner";
        vm.startPrank(address(111));
        modifierTest(callee, calldata_, revertMessage);
    }

    function whenPausedTest(
        address callee,
        bytes memory calldata_
    ) public override {
        string memory revertMessage = "PantosHub: not paused";
        modifierTest(callee, calldata_, revertMessage);
    }

    function whenNotPausedTest(
        address callee,
        bytes memory calldata_
    ) public override {
        string memory revertMessage = "PantosHub: paused";
        modifierTest(callee, calldata_, revertMessage);
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

    function mockPantosForwarder_verifyTransfer(
        address pantosForwarder,
        PantosTypes.TransferRequest memory request,
        bytes memory signature
    ) public {
        vm.mockCall(
            pantosForwarder,
            abi.encodeWithSelector(
                PantosForwarder.verifyTransfer.selector,
                request,
                signature
            ),
            abi.encode()
        );
    }

    function mockPantosForwarder_verifyTransferFrom(
        address pantosForwarder,
        PantosTypes.TransferFromRequest memory request,
        bytes memory signature
    ) public {
        vm.mockCall(
            pantosForwarder,
            abi.encodeWithSelector(
                PantosForwarder.verifyTransferFrom.selector,
                request,
                signature
            ),
            abi.encode()
        );
    }

    function mockPantosForwarder_verifyTransferTo(
        address pantosForwarder,
        PantosTypes.TransferToRequest memory request,
        address[] memory signerAddresses,
        bytes[] memory signatures
    ) public {
        vm.mockCall(
            pantosForwarder,
            abi.encodeWithSelector(
                PantosForwarder.verifyTransferTo.selector,
                request,
                signerAddresses,
                signatures
            ),
            abi.encode()
        );
    }

    function mockPantosForwarder_verifyAndForwardTransfer(
        address pantosForwarder,
        PantosTypes.TransferRequest memory request,
        bytes memory signature
    ) public {
        vm.mockCall(
            pantosForwarder,
            abi.encodeWithSelector(
                PantosForwarder.verifyAndForwardTransfer.selector,
                request,
                signature
            ),
            abi.encode()
        );
    }

    function mockPantosForwarder_verifyAndForwardTransferFrom(
        address pantosForwarder,
        PantosTypes.TransferFromRequest memory request,
        bytes memory signature
    ) public {
        vm.mockCall(
            pantosForwarder,
            abi.encodeWithSelector(
                PantosForwarder.verifyAndForwardTransferFrom.selector,
                request,
                signature
            ),
            abi.encode()
        );
    }

    function mockPantosForwarder_verifyAndForwardTransferTo(
        address pantosForwarder,
        PantosTypes.TransferToRequest memory request,
        address[] memory signerAddresses,
        bytes[] memory signatures
    ) public {
        vm.mockCall(
            pantosForwarder,
            abi.encodeWithSelector(
                PantosForwarder.verifyAndForwardTransferTo.selector,
                request,
                signerAddresses,
                signatures
            ),
            abi.encode()
        );
    }

    function mockPantosForwarder_isValidValidatorNodeNonce(
        address pantosForwarder,
        uint256 nonce,
        bool success
    ) public {
        vm.mockCall(
            pantosForwarder,
            abi.encodeWithSelector(
                PantosForwarder.isValidValidatorNodeNonce.selector,
                nonce
            ),
            abi.encode(success)
        );
    }

    function mockPantosForwarder_isValidSenderNonce(
        address pantosForwarder,
        address sender,
        uint256 nonce,
        bool success
    ) public {
        vm.mockCall(
            pantosForwarder,
            abi.encodeWithSelector(
                PantosForwarder.isValidSenderNonce.selector,
                sender,
                nonce
            ),
            abi.encode(success)
        );
    }

    function registerToken() public {
        initializePantosHub();
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, deployer());
        pantosHubProxy.registerToken(PANDAS_TOKEN_ADDRESS);
    }

    function registerTokenAndExternalToken() public {
        registerToken();
        pantosHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function registerServiceNode() public {
        initializePantosHub();
        mockIerc20_transferFrom(
            PANTOS_TOKEN_ADDRESS,
            SERVICE_NODE_ADDRESS,
            address(pantosHubProxy),
            MINIMUM_SERVICE_NODE_DEPOSIT,
            true
        );
        vm.prank(SERVICE_NODE_ADDRESS);
        pantosHubProxy.registerServiceNode(
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
    }

    function unregisterServicenode() public {
        initializePantosHub();
        vm.prank(SERVICE_NODE_ADDRESS);
        pantosHubProxy.unregisterServiceNode(SERVICE_NODE_ADDRESS);
    }
}
