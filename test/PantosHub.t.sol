// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PantosTypes} from "../src/interfaces/PantosTypes.sol";
import {IPantosForwarder} from "../src/interfaces/IPantosForwarder.sol";
import {IPantosRegistry} from "../src/interfaces/IPantosRegistry.sol";
import {IPantosTransfer} from "../src/interfaces/IPantosTransfer.sol";
import {PantosBaseToken} from "../src/PantosBaseToken.sol";
import {PantosForwarder} from "../src/PantosForwarder.sol";
import {AccessController} from "../src/access/AccessController.sol";

import {PantosHubDeployer} from "./PantosHubDeployer.t.sol";

contract PantosHubTest is PantosHubDeployer {
    address constant PANDAS_TOKEN_OWNER =
        address(uint160(uint256(keccak256("PandasTokenOwner"))));
    AccessController public accessController;

    function setUp() public {
        vm.warp(BLOCK_TIMESTAMP);
        accessController = deployAccessController();
        deployPantosHub(accessController);
    }

    function test_SetUpState() external view {
        checkStatePantosHubAfterDeployment();
    }

    function test_PantosHubInitialization() external {
        initializePantosHub();
        checkStatePantosHubAfterInit();
    }

    function test_pause_AfterInitialization() external {
        initializePantosHub();
        vm.expectEmit(address(pantosHubProxy));
        emit IPantosRegistry.Paused(PAUSER);

        vm.prank(PAUSER);
        pantosHubProxy.pause();

        assertTrue(pantosHubProxy.paused());
    }

    function test_pause_WhenPaused() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.pause.selector
        );

        whenNotPausedTest(address(pantosHubProxy), calldata_);
    }

    function test_pause_ByNonPauser() external {
        initializePantosHub();
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.pause.selector
        );

        onlyRoleTest(address(pantosHubProxy), calldata_);
    }

    function test_unpause_AfterDeploy() external {
        _initializePantosHubValues();
        vm.expectEmit(address(pantosHubProxy));
        emit IPantosRegistry.Unpaused(SUPER_CRITICAL_OPS);

        vm.prank(SUPER_CRITICAL_OPS);
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

    function test_unpause_ByNonSuperCriticalOps() external {
        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.unpause.selector
        );

        onlyRoleTest(address(pantosHubProxy), calldata_);
    }

    function test_unpause_WithNoForwarderSet() external {
        vm.expectRevert(
            abi.encodePacked("PantosHub: PantosForwarder has not been set")
        );

        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.unpause();
    }

    function test_unpause_WithNoPantosTokenSet() external {
        vm.startPrank(SUPER_CRITICAL_OPS);
        pantosHubProxy.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        vm.expectRevert(
            abi.encodePacked("PantosHub: PantosToken has not been set")
        );

        pantosHubProxy.unpause();
    }

    function test_unpause_WithNoPrimaryValidatorNodeSet() external {
        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        mockPandasToken_getOwner(PANTOS_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);
        mockPandasToken_getPantosForwarder(
            PANTOS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        vm.startPrank(SUPER_CRITICAL_OPS);
        pantosHubProxy.setPantosToken(PANTOS_TOKEN_ADDRESS);
        vm.expectRevert(
            abi.encodePacked(
                "PantosHub: primary validator node has not been set"
            )
        );

        pantosHubProxy.unpause();
        vm.stopPrank();
    }

    function test_setPantosForwarder() external {
        vm.expectEmit(address(pantosHubProxy));
        emit IPantosRegistry.PantosForwarderSet(PANTOS_FORWARDER_ADDRESS);

        vm.prank(SUPER_CRITICAL_OPS);
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

    function test_setPantosForwarder_ByNonSuperCriticalOps() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.setPantosForwarder.selector,
            PANTOS_FORWARDER_ADDRESS
        );

        onlyRoleTest(address(pantosHubProxy), calldata_);
    }

    function test_setPantosForwarder_WithForwarderAddress0() external {
        vm.expectRevert(
            abi.encodePacked(
                "PantosHub: PantosForwarder must not be the zero account"
            )
        );

        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.setPantosForwarder(ADDRESS_ZERO);
    }

    function test_setPantosToken() external {
        mockPandasToken_getOwner(PANTOS_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);
        mockPandasToken_getPantosForwarder(
            PANTOS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        vm.startPrank(SUPER_CRITICAL_OPS);
        pantosHubProxy.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
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

    function test_setPantosToken_ByNonSuperCriticalOps() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.setPantosToken.selector,
            PANTOS_TOKEN_ADDRESS
        );

        onlyRoleTest(address(pantosHubProxy), calldata_);
    }

    function test_setPantosToken_WithPantosToken0() external {
        vm.expectRevert("PantosHub: PantosToken must not be the zero account");

        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.setPantosToken(ADDRESS_ZERO);
    }

    function test_setPantosToken_AlreadySet() external {
        mockPandasToken_getOwner(PANTOS_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);
        mockPandasToken_getPantosForwarder(
            PANTOS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        vm.startPrank(SUPER_CRITICAL_OPS);
        pantosHubProxy.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        pantosHubProxy.setPantosToken(PANTOS_TOKEN_ADDRESS);
        vm.expectRevert("PantosHub: PantosToken already set");

        pantosHubProxy.setPantosToken(PANTOS_TOKEN_ADDRESS);
    }

    function test_setPrimaryValidatorNode() external {
        vm.expectEmit(address(pantosHubProxy));
        emit IPantosRegistry.PrimaryValidatorNodeUpdated(validatorAddress);

        vm.prank(SUPER_CRITICAL_OPS);
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

    function test_setPrimaryValidatorNode_ByNonSuperCriticalOps() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.setPrimaryValidatorNode.selector,
            validatorAddress
        );

        onlyRoleTest(address(pantosHubProxy), calldata_);
    }

    function test_setProtocolVersion() external {
        vm.expectEmit(address(pantosHubProxy));
        emit IPantosRegistry.ProtocolVersionUpdated(PROTOCOL_VERSION);

        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.setProtocolVersion(PROTOCOL_VERSION);

        assertEq(pantosHubProxy.getProtocolVersion(), PROTOCOL_VERSION);
    }

    function test_setProtocolVersion_WhenNotPaused() public {
        initializePantosHub();
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.setProtocolVersion.selector,
            PROTOCOL_VERSION
        );

        whenPausedTest(address(pantosHubProxy), calldata_);
    }

    function test_setProtocolVersion_ByNonSuperCriticalOps() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.setProtocolVersion.selector,
            PROTOCOL_VERSION
        );

        onlyRoleTest(address(pantosHubProxy), calldata_);
    }

    function test_registerBlockchain() external {
        vm.expectEmit();
        emit IPantosRegistry.BlockchainRegistered(
            uint256(otherBlockchain.blockchainId),
            otherBlockchain.feeFactor
        );

        registerOtherBlockchainAtPantosHub();

        PantosTypes.BlockchainRecord
            memory otherBlockchainRecord = pantosHubProxy.getBlockchainRecord(
                uint256(otherBlockchain.blockchainId)
            );
        PantosTypes.UpdatableUint256
            memory otherBlockchainValidatorFeeFactor = pantosHubProxy
                .getValidatorFeeFactor(uint256(otherBlockchain.blockchainId));
        assertEq(otherBlockchainRecord.name, otherBlockchain.name);
        assertEq(otherBlockchainRecord.active, true);
        assertEq(pantosHubProxy.getNumberBlockchains(), 2);
        assertEq(pantosHubProxy.getNumberActiveBlockchains(), 2);
        assertEq(
            otherBlockchainValidatorFeeFactor.currentValue,
            otherBlockchain.feeFactor
        );
        assertEq(otherBlockchainValidatorFeeFactor.pendingValue, 0);
        assertEq(otherBlockchainValidatorFeeFactor.updateTime, 0);
    }

    function test_registerBlockchain_AgainAfterUnregistration() external {
        registerOtherBlockchainAtPantosHub();
        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.unregisterBlockchain(
            uint256(otherBlockchain.blockchainId)
        );
        vm.expectEmit();
        emit IPantosRegistry.BlockchainRegistered(
            uint256(otherBlockchain.blockchainId),
            otherBlockchain.feeFactor
        );

        registerOtherBlockchainAtPantosHub();

        PantosTypes.BlockchainRecord
            memory otherBlockchainRecord = pantosHubProxy.getBlockchainRecord(
                uint256(otherBlockchain.blockchainId)
            );
        PantosTypes.UpdatableUint256
            memory otherBlockchainValidatorFeeFactor = pantosHubProxy
                .getValidatorFeeFactor(uint256(otherBlockchain.blockchainId));
        assertEq(otherBlockchainRecord.name, otherBlockchain.name);
        assertEq(otherBlockchainRecord.active, true);
        assertEq(pantosHubProxy.getNumberBlockchains(), 2);
        assertEq(pantosHubProxy.getNumberActiveBlockchains(), 2);
        assertEq(
            otherBlockchainValidatorFeeFactor.currentValue,
            otherBlockchain.feeFactor
        );
        assertEq(otherBlockchainValidatorFeeFactor.pendingValue, 0);
        assertEq(otherBlockchainValidatorFeeFactor.updateTime, 0);
    }

    function test_registerBlockchain_ByNonSuperCriticalOps() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.registerBlockchain.selector,
            uint256(otherBlockchain.blockchainId),
            otherBlockchain.name,
            otherBlockchain.feeFactor
        );

        onlyRoleTest(address(pantosHubProxy), calldata_);
    }

    function test_registerBlockchain_WithEmptyName() external {
        vm.expectRevert("PantosHub: blockchain name must not be empty");

        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.registerBlockchain(
            uint256(otherBlockchain.blockchainId),
            "",
            otherBlockchain.feeFactor
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

        vm.prank(SUPER_CRITICAL_OPS);
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

    function test_unregisterBlockchain_ByNonSuperCriticalOps() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.unregisterBlockchain.selector,
            uint256(otherBlockchain.blockchainId)
        );

        onlyRoleTest(address(pantosHubProxy), calldata_);
    }

    function test_unregisterBlockchain_WithCurrentBlockchain() external {
        vm.expectRevert(
            "PantosHub: blockchain ID must not be the current blockchain ID"
        );

        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.unregisterBlockchain(
            uint256(thisBlockchain.blockchainId)
        );
    }

    function test_unregisterBlockchain_WhenBlockchainNotRegistered() external {
        vm.expectRevert("PantosHub: blockchain must be active");

        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.unregisterBlockchain(
            uint256(type(BlockchainId).max) + 1
        );
    }

    function test_unregisterBlockchain_AlreadyUnregistered() external {
        registerOtherBlockchainAtPantosHub();
        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.unregisterBlockchain(
            uint256(otherBlockchain.blockchainId)
        );
        vm.expectRevert("PantosHub: blockchain must be active");

        vm.prank(SUPER_CRITICAL_OPS);
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

        vm.prank(MEDIUM_CRITICAL_OPS);
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

    function test_updateBlockchainName_ByNonMediumCriticalOps() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.updateBlockchainName.selector,
            uint256(thisBlockchain.blockchainId),
            "new name"
        );

        onlyRoleTest(address(pantosHubProxy), calldata_);
    }

    function test_updateBlockchainName_WithEmptyName() external {
        vm.expectRevert("PantosHub: blockchain name must not be empty");

        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.updateBlockchainName(
            uint256(thisBlockchain.blockchainId),
            ""
        );
    }

    function test_updateBlockchainName_WhenBlockchainNotRegistered() external {
        vm.expectRevert("PantosHub: blockchain must be active");

        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.updateBlockchainName(
            uint256(type(BlockchainId).max) + 1,
            "new name"
        );
    }

    function test_updateBlockchainName_WhenBlockchainUnregistered() external {
        registerOtherBlockchainAtPantosHub();
        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.unregisterBlockchain(
            uint256(otherBlockchain.blockchainId)
        );
        vm.expectRevert("PantosHub: blockchain must be active");

        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.updateBlockchainName(
            uint256(otherBlockchain.blockchainId),
            "new name"
        );
    }

    function test_initiateValidatorFeeFactorUpdate() external {
        initializePantosHub();
        uint256 blockchainId = uint256(thisBlockchain.blockchainId);
        uint256 currentValue = thisBlockchain.feeFactor;
        uint256 newValue = currentValue + 1;
        uint256 updateTime = BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY;

        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubValidatorFeeFactor(blockchainId);
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, 0);
        assertEq(storedStruct.updateTime, 0);

        vm.expectEmit();
        emit IPantosRegistry.ValidatorFeeFactorUpdateInitiated(
            blockchainId,
            newValue,
            updateTime
        );

        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateValidatorFeeFactorUpdate(
            blockchainId,
            newValue
        );

        storedStruct = loadPantosHubValidatorFeeFactor(blockchainId);
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, newValue);
        assertEq(storedStruct.updateTime, updateTime);
    }

    function test_initiateValidatorFeeFactorUpdate_ByNonMediumCriticalOps()
        external
    {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.initiateValidatorFeeFactorUpdate.selector,
            uint256(thisBlockchain.blockchainId),
            thisBlockchain.feeFactor + 1
        );

        onlyRoleTest(address(pantosHubProxy), calldata_);
    }

    function test_initiateValidatorFeeFactorUpdate_ZeroFeeFactor() external {
        initializePantosHub();
        vm.expectRevert("PantosHub: new validator fee factor must be >= 1");

        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateValidatorFeeFactorUpdate(
            uint256(thisBlockchain.blockchainId),
            0
        );
    }

    function test_initiateValidatorFeeFactorUpdate_InactiveBlockchain()
        external
    {
        initializePantosHub();
        vm.expectRevert("PantosHub: blockchain must be active");

        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateValidatorFeeFactorUpdate(
            uint256(type(BlockchainId).max) + 1,
            thisBlockchain.feeFactor + 1
        );
    }

    function test_executeValidatorFeeFactorUpdate() external {
        initializePantosHub();
        uint256 blockchainId = uint256(thisBlockchain.blockchainId);
        uint256 currentValue = thisBlockchain.feeFactor;
        uint256 newValue = currentValue + 1;
        uint256 updateTime = BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY;
        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateValidatorFeeFactorUpdate(
            blockchainId,
            newValue
        );
        vm.warp(updateTime);

        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubValidatorFeeFactor(blockchainId);
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, newValue);
        assertEq(storedStruct.updateTime, updateTime);

        vm.expectEmit();
        emit IPantosRegistry.ValidatorFeeFactorUpdateExecuted(
            blockchainId,
            newValue
        );

        pantosHubProxy.executeValidatorFeeFactorUpdate(blockchainId);

        storedStruct = loadPantosHubValidatorFeeFactor(blockchainId);
        assertEq(storedStruct.currentValue, newValue);
    }

    function test_executeValidatorFeeFactorUpdate_InactiveBlockchain()
        external
    {
        initializePantosHub();
        vm.expectRevert("PantosHub: blockchain must be active");

        pantosHubProxy.executeValidatorFeeFactorUpdate(
            uint256(type(BlockchainId).max) + 1
        );
    }

    function test_executeValidatorFeeFactorUpdate_NoUpdateTime() external {
        initializePantosHub();
        uint256 blockchainId = uint256(thisBlockchain.blockchainId);
        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubValidatorFeeFactor(blockchainId);
        assertEq(storedStruct.updateTime, 0);

        vm.expectRevert("PantosHub: no pending update");

        pantosHubProxy.executeValidatorFeeFactorUpdate(blockchainId);
    }

    function test_executeValidatorFeeFactorUpdate_NoUpdatedValue() external {
        initializePantosHub();
        uint256 blockchainId = uint256(thisBlockchain.blockchainId);
        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateValidatorFeeFactorUpdate(
            blockchainId,
            thisBlockchain.feeFactor
        );
        vm.warp(BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY);

        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubValidatorFeeFactor(blockchainId);
        assertEq(storedStruct.pendingValue, storedStruct.currentValue);
        assertGt(storedStruct.updateTime, 0);

        vm.expectRevert("PantosHub: no pending update");

        pantosHubProxy.executeValidatorFeeFactorUpdate(blockchainId);
    }

    function test_executeValidatorFeeFactorUpdate_TooEarly() external {
        initializePantosHub();
        uint256 blockchainId = uint256(thisBlockchain.blockchainId);
        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateValidatorFeeFactorUpdate(
            blockchainId,
            thisBlockchain.feeFactor + 1
        );

        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubValidatorFeeFactor(blockchainId);
        assertNotEq(storedStruct.pendingValue, storedStruct.currentValue);
        assertGt(storedStruct.updateTime, 0);
        assertLt(BLOCK_TIMESTAMP, storedStruct.updateTime);

        vm.expectRevert("PantosHub: update time not reached");

        pantosHubProxy.executeValidatorFeeFactorUpdate(blockchainId);
    }

    function test_initiateUnbondingPeriodServiceNodeDepositUpdate() external {
        initializePantosHub();
        uint256 currentValue = SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD;
        uint256 newValue = currentValue + 1;
        uint256 updateTime = BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY;

        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubUnbondingPeriodServiceNodeDeposit();
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, 0);
        assertEq(storedStruct.updateTime, 0);

        vm.expectEmit();
        emit IPantosRegistry.UnbondingPeriodServiceNodeDepositUpdateInitiated(
            newValue,
            updateTime
        );

        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateUnbondingPeriodServiceNodeDepositUpdate(
            newValue
        );

        storedStruct = loadPantosHubUnbondingPeriodServiceNodeDeposit();
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, newValue);
        assertEq(storedStruct.updateTime, updateTime);
    }

    function test_initiateUnbondingPeriodServiceNodeDepositUpdate_ByNonMediumCriticalOps()
        external
    {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry
                .initiateUnbondingPeriodServiceNodeDepositUpdate
                .selector,
            SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD + 1
        );

        onlyRoleTest(address(pantosHubProxy), calldata_);
    }

    function test_executeUnbondingPeriodServiceNodeDepositUpdate() external {
        initializePantosHub();
        uint256 currentValue = SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD;
        uint256 newValue = currentValue + 1;
        uint256 updateTime = BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY;
        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateUnbondingPeriodServiceNodeDepositUpdate(
            newValue
        );
        vm.warp(updateTime);

        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubUnbondingPeriodServiceNodeDeposit();
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, newValue);
        assertEq(storedStruct.updateTime, updateTime);

        vm.expectEmit();
        emit IPantosRegistry.UnbondingPeriodServiceNodeDepositUpdateExecuted(
            newValue
        );

        pantosHubProxy.executeUnbondingPeriodServiceNodeDepositUpdate();

        storedStruct = loadPantosHubUnbondingPeriodServiceNodeDeposit();
        assertEq(storedStruct.currentValue, newValue);
    }

    function test_executeUnbondingPeriodServiceNodeDepositUpdate_NoUpdateTime()
        external
    {
        initializePantosHub();
        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubUnbondingPeriodServiceNodeDeposit();
        assertEq(storedStruct.updateTime, 0);

        vm.expectRevert("PantosHub: no pending update");

        pantosHubProxy.executeUnbondingPeriodServiceNodeDepositUpdate();
    }

    function test_executeUnbondingPeriodServiceNodeDepositUpdate_NoUpdatedValue()
        external
    {
        initializePantosHub();
        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateUnbondingPeriodServiceNodeDepositUpdate(
            SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD
        );
        vm.warp(BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY);

        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubUnbondingPeriodServiceNodeDeposit();
        assertEq(storedStruct.pendingValue, storedStruct.currentValue);
        assertGt(storedStruct.updateTime, 0);

        vm.expectRevert("PantosHub: no pending update");

        pantosHubProxy.executeUnbondingPeriodServiceNodeDepositUpdate();
    }

    function test_executeUnbondingPeriodServiceNodeDepositUpdate_TooEarly()
        external
    {
        initializePantosHub();
        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateUnbondingPeriodServiceNodeDepositUpdate(
            SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD + 1
        );

        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubUnbondingPeriodServiceNodeDeposit();
        assertNotEq(storedStruct.pendingValue, storedStruct.currentValue);
        assertGt(storedStruct.updateTime, 0);
        assertLt(BLOCK_TIMESTAMP, storedStruct.updateTime);

        vm.expectRevert("PantosHub: update time not reached");

        pantosHubProxy.executeUnbondingPeriodServiceNodeDepositUpdate();
    }

    function test_initiateMinimumServiceNodeDepositUpdate() external {
        initializePantosHub();
        uint256 currentValue = MINIMUM_SERVICE_NODE_DEPOSIT;
        uint256 newValue = currentValue + 1;
        uint256 updateTime = BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY;

        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubMinimumServiceNodeDeposit();
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, 0);
        assertEq(storedStruct.updateTime, 0);

        vm.expectEmit();
        emit IPantosRegistry.MinimumServiceNodeDepositUpdateInitiated(
            newValue,
            updateTime
        );

        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateMinimumServiceNodeDepositUpdate(newValue);

        storedStruct = loadPantosHubMinimumServiceNodeDeposit();
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, newValue);
        assertEq(storedStruct.updateTime, updateTime);
    }

    function test_initiateMinimumServiceNodeDepositUpdate_ByNonMediumCriticalOps()
        external
    {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.initiateMinimumServiceNodeDepositUpdate.selector,
            MINIMUM_SERVICE_NODE_DEPOSIT + 1
        );

        onlyRoleTest(address(pantosHubProxy), calldata_);
    }

    function test_executeMinimumServiceNodeDepositUpdate() external {
        initializePantosHub();
        uint256 currentValue = MINIMUM_SERVICE_NODE_DEPOSIT;
        uint256 newValue = currentValue + 1;
        uint256 updateTime = BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY;
        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateMinimumServiceNodeDepositUpdate(newValue);
        vm.warp(updateTime);

        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubMinimumServiceNodeDeposit();
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, newValue);
        assertEq(storedStruct.updateTime, updateTime);

        vm.expectEmit();
        emit IPantosRegistry.MinimumServiceNodeDepositUpdateExecuted(newValue);

        pantosHubProxy.executeMinimumServiceNodeDepositUpdate();

        storedStruct = loadPantosHubMinimumServiceNodeDeposit();
        assertEq(storedStruct.currentValue, newValue);
    }

    function test_executeMinimumServiceNodeDepositUpdate_NoUpdateTime()
        external
    {
        initializePantosHub();
        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubMinimumServiceNodeDeposit();
        assertEq(storedStruct.updateTime, 0);

        vm.expectRevert("PantosHub: no pending update");

        pantosHubProxy.executeMinimumServiceNodeDepositUpdate();
    }

    function test_executeMinimumServiceNodeDepositUpdate_NoUpdatedValue()
        external
    {
        initializePantosHub();
        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateMinimumServiceNodeDepositUpdate(
            MINIMUM_SERVICE_NODE_DEPOSIT
        );
        vm.warp(BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY);

        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubMinimumServiceNodeDeposit();
        assertEq(storedStruct.pendingValue, storedStruct.currentValue);
        assertGt(storedStruct.updateTime, 0);

        vm.expectRevert("PantosHub: no pending update");

        pantosHubProxy.executeMinimumServiceNodeDepositUpdate();
    }

    function test_executeMinimumServiceNodeDepositUpdate_TooEarly() external {
        initializePantosHub();
        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateMinimumServiceNodeDepositUpdate(
            MINIMUM_SERVICE_NODE_DEPOSIT + 1
        );

        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubMinimumServiceNodeDeposit();
        assertNotEq(storedStruct.pendingValue, storedStruct.currentValue);
        assertGt(storedStruct.updateTime, 0);
        assertLt(BLOCK_TIMESTAMP, storedStruct.updateTime);

        vm.expectRevert("PantosHub: update time not reached");

        pantosHubProxy.executeMinimumServiceNodeDepositUpdate();
    }

    function test_initiateParameterUpdateDelayUpdate() external {
        initializePantosHub();
        uint256 currentValue = PARAMETER_UPDATE_DELAY;
        uint256 newValue = currentValue + 1;
        uint256 updateTime = BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY;

        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubParameterUpdateDelay();
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, 0);
        assertEq(storedStruct.updateTime, 0);

        vm.expectEmit();
        emit IPantosRegistry.ParameterUpdateDelayUpdateInitiated(
            newValue,
            updateTime
        );

        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateParameterUpdateDelayUpdate(newValue);

        storedStruct = loadPantosHubParameterUpdateDelay();
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, newValue);
        assertEq(storedStruct.updateTime, updateTime);
    }

    function test_initiateParameterUpdateDelayUpdate_ByNonMediumCriticalOps()
        external
    {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.initiateParameterUpdateDelayUpdate.selector,
            PARAMETER_UPDATE_DELAY + 1
        );

        onlyRoleTest(address(pantosHubProxy), calldata_);
    }

    function test_executeParameterUpdateDelayUpdate() external {
        initializePantosHub();
        uint256 currentValue = PARAMETER_UPDATE_DELAY;
        uint256 newValue = currentValue + 1;
        uint256 updateTime = BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY;
        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateParameterUpdateDelayUpdate(newValue);
        vm.warp(updateTime);

        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubParameterUpdateDelay();
        assertEq(storedStruct.currentValue, currentValue);
        assertEq(storedStruct.pendingValue, newValue);
        assertEq(storedStruct.updateTime, updateTime);

        vm.expectEmit();
        emit IPantosRegistry.ParameterUpdateDelayUpdateExecuted(newValue);

        pantosHubProxy.executeParameterUpdateDelayUpdate();

        storedStruct = loadPantosHubParameterUpdateDelay();
        assertEq(storedStruct.currentValue, newValue);
    }

    function test_executeParameterUpdateDelayUpdate_NoUpdateTime() external {
        initializePantosHub();
        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubParameterUpdateDelay();
        assertEq(storedStruct.updateTime, 0);

        vm.expectRevert("PantosHub: no pending update");

        pantosHubProxy.executeParameterUpdateDelayUpdate();
    }

    function test_executeParameterUpdateDelayUpdate_NoUpdatedValue() external {
        initializePantosHub();
        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateParameterUpdateDelayUpdate(
            PARAMETER_UPDATE_DELAY
        );
        vm.warp(BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY);

        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubParameterUpdateDelay();
        assertEq(storedStruct.pendingValue, storedStruct.currentValue);
        assertGt(storedStruct.updateTime, 0);

        vm.expectRevert("PantosHub: no pending update");

        pantosHubProxy.executeParameterUpdateDelayUpdate();
    }

    function test_executeParameterUpdateDelayUpdate_TooEarly() external {
        initializePantosHub();
        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateParameterUpdateDelayUpdate(
            PARAMETER_UPDATE_DELAY + 1
        );

        PantosTypes.UpdatableUint256 memory storedStruct;
        storedStruct = loadPantosHubParameterUpdateDelay();
        assertNotEq(storedStruct.pendingValue, storedStruct.currentValue);
        assertGt(storedStruct.updateTime, 0);
        assertLt(BLOCK_TIMESTAMP, storedStruct.updateTime);

        vm.expectRevert("PantosHub: update time not reached");

        pantosHubProxy.executeParameterUpdateDelayUpdate();
    }

    function test_registerToken() external {
        initializePantosHub();
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, PANDAS_TOKEN_OWNER);
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        assertFalse(inArray(PANDAS_TOKEN_ADDRESS, loadPantosHubTokens()));
        vm.expectEmit();
        emit IPantosRegistry.TokenRegistered(PANDAS_TOKEN_ADDRESS);

        vm.prank(PANDAS_TOKEN_OWNER);
        pantosHubProxy.registerToken(PANDAS_TOKEN_ADDRESS);

        PantosTypes.TokenRecord memory tokenRecord = pantosHubProxy
            .getTokenRecord(PANDAS_TOKEN_ADDRESS);
        assertTrue(tokenRecord.active);
        assertTrue(inArray(PANDAS_TOKEN_ADDRESS, loadPantosHubTokens()));
        checkTokenIndices();
    }

    function test_registerToken_BySuperCriticalOps() external {
        initializePantosHub();
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        assertFalse(inArray(PANDAS_TOKEN_ADDRESS, loadPantosHubTokens()));
        vm.expectEmit();
        emit IPantosRegistry.TokenRegistered(PANDAS_TOKEN_ADDRESS);

        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.registerToken(PANDAS_TOKEN_ADDRESS);

        PantosTypes.TokenRecord memory tokenRecord = pantosHubProxy
            .getTokenRecord(PANDAS_TOKEN_ADDRESS);
        assertTrue(tokenRecord.active);
        assertTrue(inArray(PANDAS_TOKEN_ADDRESS, loadPantosHubTokens()));
        checkTokenIndices();
    }

    function test_registerToken_BySuperCriticalOpsWhenPaused() external {
        initializePantosHub();
        vm.prank(PAUSER);
        pantosHubProxy.pause();

        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        assertFalse(inArray(PANDAS_TOKEN_ADDRESS, loadPantosHubTokens()));
        vm.expectEmit();
        emit IPantosRegistry.TokenRegistered(PANDAS_TOKEN_ADDRESS);

        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.registerToken(PANDAS_TOKEN_ADDRESS);

        PantosTypes.TokenRecord memory tokenRecord = pantosHubProxy
            .getTokenRecord(PANDAS_TOKEN_ADDRESS);
        assertTrue(tokenRecord.active);
        assertTrue(inArray(PANDAS_TOKEN_ADDRESS, loadPantosHubTokens()));
        checkTokenIndices();
    }

    function test_registerToken_ByNonSuperCriticalOpsWhenPaused() external {
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, PANDAS_TOKEN_OWNER);
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.registerToken.selector,
            PANDAS_TOKEN_ADDRESS
        );

        onlyRoleTest(address(pantosHubProxy), calldata_);
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

    function test_registerToken_WithNonMatchingForwarder() external {
        address nonMatchingForwarderAddress = PANTOS_TOKEN_ADDRESS;
        assertNotEq(nonMatchingForwarderAddress, PANTOS_FORWARDER_ADDRESS);
        initializePantosHub();
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, PANDAS_TOKEN_OWNER);
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            nonMatchingForwarderAddress
        );

        vm.expectRevert("PantosHub: PantosForwarder must match");

        vm.prank(PANDAS_TOKEN_OWNER);
        pantosHubProxy.registerToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_registerToken_WhenTokenAlreadyRegistered() external {
        registerToken();
        vm.expectRevert("PantosHub: token must not be active");

        vm.prank(PANDAS_TOKEN_OWNER);
        pantosHubProxy.registerToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_registerToken_WhenTokenAlreadyRegisteredBySuperCriticalOps()
        external
    {
        registerTokenBySuperCriticalOps();
        vm.expectRevert("PantosHub: token must not be active");

        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.registerToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_unregisterToken() external {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, PANDAS_TOKEN_OWNER);
        vm.expectEmit();
        emit IPantosRegistry.ExternalTokenUnregistered(
            PANDAS_TOKEN_ADDRESS,
            EXTERNAL_PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
        vm.expectEmit();
        emit IPantosRegistry.TokenUnregistered(PANDAS_TOKEN_ADDRESS);

        vm.prank(PANDAS_TOKEN_OWNER);
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
        checkTokenIndices();
    }

    function test_unregisterToken_BySuperCriticalOps() external {
        registerTokenAndExternalToken(SUPER_CRITICAL_OPS);
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);
        vm.expectEmit();
        emit IPantosRegistry.ExternalTokenUnregistered(
            PANDAS_TOKEN_ADDRESS,
            EXTERNAL_PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
        vm.expectEmit();
        emit IPantosRegistry.TokenUnregistered(PANDAS_TOKEN_ADDRESS);

        vm.prank(SUPER_CRITICAL_OPS);
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
        checkTokenIndices();
    }

    function test_unregisterToken_BySuperCriticalOpsWhenPaused() external {
        registerTokenAndExternalToken(SUPER_CRITICAL_OPS);

        vm.prank(PAUSER);
        pantosHubProxy.pause();

        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);
        vm.expectEmit();
        emit IPantosRegistry.ExternalTokenUnregistered(
            PANDAS_TOKEN_ADDRESS,
            EXTERNAL_PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
        vm.expectEmit();
        emit IPantosRegistry.TokenUnregistered(PANDAS_TOKEN_ADDRESS);

        vm.prank(SUPER_CRITICAL_OPS);
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
        checkTokenIndices();
    }

    function test_unregisterToken_ByNonSuperCriticalOpsWhenPaused() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.unregisterToken.selector,
            PANDAS_TOKEN_ADDRESS
        );

        onlyRoleTest(address(pantosHubProxy), calldata_);
    }

    function test_unregisterToken_WhenTokenNotRegistered() external {
        initializePantosHub();
        vm.expectRevert("PantosHub: token must be active");

        vm.prank(PANDAS_TOKEN_OWNER);
        pantosHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_unregisterToken_WhenTokenNotRegisteredBySuperCriticalOps()
        external
    {
        initializePantosHub();
        vm.expectRevert("PantosHub: token must be active");

        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_unregisterToken_WhenTokenNotRegisteredBySuperCriticalOpsWhenPaused()
        external
    {
        vm.expectRevert("PantosHub: token must be active");

        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
    }

    function test_unregisterToken_WhenTokenAlreadyUnRegistered() external {
        registerToken();
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, PANDAS_TOKEN_OWNER);

        vm.startPrank(PANDAS_TOKEN_OWNER);
        pantosHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
        vm.expectRevert("PantosHub: token must be active");

        pantosHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
        vm.stopPrank();
    }

    function test_unregisterToken_WhenTokenAlreadyUnRegisteredBySuperCriticalOps()
        external
    {
        registerTokenBySuperCriticalOps();
        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);

        vm.startPrank(SUPER_CRITICAL_OPS);
        pantosHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
        vm.expectRevert("PantosHub: token must be active");

        pantosHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
        vm.stopPrank();
    }

    function test_unregisterToken_WhenTokenAlreadyUnRegistered_BySuperCriticalOpsWhenPaused()
        external
    {
        registerTokenBySuperCriticalOps();
        vm.prank(PAUSER);
        pantosHubProxy.pause();

        mockPandasToken_getOwner(PANDAS_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);

        vm.startPrank(SUPER_CRITICAL_OPS);
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

    function test_registerToken_unregisterToken() external {
        address[] memory tokenAddresses = new address[](3);
        tokenAddresses[0] = PANDAS_TOKEN_ADDRESS;
        tokenAddresses[1] = PANDAS_TOKEN_ADDRESS_1;
        tokenAddresses[2] = PANDAS_TOKEN_ADDRESS_2;
        bool[] memory tokenRegistered = new bool[](3);
        tokenRegistered[0] = false;
        tokenRegistered[1] = false;
        tokenRegistered[2] = false;

        initializePantosHub();
        checkTokenRegistrations(tokenAddresses, tokenRegistered);

        registerToken(PANDAS_TOKEN_ADDRESS, PANDAS_TOKEN_OWNER);
        tokenRegistered[0] = true;
        checkTokenRegistrations(tokenAddresses, tokenRegistered);

        registerToken(PANDAS_TOKEN_ADDRESS_1, PANDAS_TOKEN_OWNER);
        tokenRegistered[1] = true;
        checkTokenRegistrations(tokenAddresses, tokenRegistered);

        registerToken(PANDAS_TOKEN_ADDRESS_2, PANDAS_TOKEN_OWNER);
        tokenRegistered[2] = true;
        checkTokenRegistrations(tokenAddresses, tokenRegistered);

        vm.prank(PANDAS_TOKEN_OWNER);
        pantosHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS_1);
        tokenRegistered[1] = false;
        checkTokenRegistrations(tokenAddresses, tokenRegistered);

        registerToken(PANDAS_TOKEN_ADDRESS_1, PANDAS_TOKEN_OWNER);
        tokenRegistered[1] = true;
        checkTokenRegistrations(tokenAddresses, tokenRegistered);

        vm.prank(PANDAS_TOKEN_OWNER);
        pantosHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS);
        tokenRegistered[0] = false;
        checkTokenRegistrations(tokenAddresses, tokenRegistered);

        vm.prank(PANDAS_TOKEN_OWNER);
        pantosHubProxy.unregisterToken(PANDAS_TOKEN_ADDRESS_2);
        tokenRegistered[2] = false;
        checkTokenRegistrations(tokenAddresses, tokenRegistered);

        registerToken(PANDAS_TOKEN_ADDRESS, PANDAS_TOKEN_OWNER);
        tokenRegistered[0] = true;
        checkTokenRegistrations(tokenAddresses, tokenRegistered);
    }

    function test_registerExternalToken() external {
        registerToken();

        vm.prank(PANDAS_TOKEN_OWNER);
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

    function test_registerExternalToken_BySuperCriticalOps() external {
        registerTokenBySuperCriticalOps();

        vm.prank(SUPER_CRITICAL_OPS);
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

    function test_registerExternalToken_BySuperCriticalOpsWhenPaused()
        external
    {
        registerTokenBySuperCriticalOps();
        vm.prank(PAUSER);
        pantosHubProxy.pause();

        vm.prank(SUPER_CRITICAL_OPS);
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

    function test_registerExternalToken_ByNonDeployerWhenPaused() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.registerExternalToken.selector,
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );

        onlyRoleTest(address(pantosHubProxy), calldata_);
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
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        vm.expectRevert("PantosHub: external token must not be active");

        vm.prank(PANDAS_TOKEN_OWNER);
        pantosHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_registerExternalToken_WhenAlreadyRegisteredBySuperCriticalOps()
        external
    {
        registerTokenAndExternalToken(SUPER_CRITICAL_OPS);
        vm.expectRevert("PantosHub: external token must not be active");

        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_registerExternalToken_WhenAlreadyRegisteredBySuperCriticalOpsWhenPaused()
        external
    {
        registerTokenAndExternalToken(SUPER_CRITICAL_OPS);

        vm.prank(PAUSER);
        pantosHubProxy.pause();

        vm.expectRevert("PantosHub: external token must not be active");

        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function test_unregisterExternalToken() external {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        vm.expectEmit();
        emit IPantosRegistry.ExternalTokenUnregistered(
            PANDAS_TOKEN_ADDRESS,
            EXTERNAL_PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );

        vm.prank(PANDAS_TOKEN_OWNER);
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

    function test_unregisterExternalToken_BySuperCriticalOps() external {
        registerTokenAndExternalToken(SUPER_CRITICAL_OPS);
        vm.expectEmit();
        emit IPantosRegistry.ExternalTokenUnregistered(
            PANDAS_TOKEN_ADDRESS,
            EXTERNAL_PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );

        vm.prank(SUPER_CRITICAL_OPS);
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

    function test_unregisterExternalToken_BySuperCriticalOpsWhenPaused()
        external
    {
        registerTokenAndExternalToken(SUPER_CRITICAL_OPS);

        vm.prank(PAUSER);
        pantosHubProxy.pause();

        vm.expectEmit();
        emit IPantosRegistry.ExternalTokenUnregistered(
            PANDAS_TOKEN_ADDRESS,
            EXTERNAL_PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );

        vm.prank(SUPER_CRITICAL_OPS);
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

    function test_unregisterExternalToken_ByNonDeployerWhenPaused() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            IPantosRegistry.unregisterExternalToken.selector,
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );

        onlyRoleTest(address(pantosHubProxy), calldata_);
    }

    function test_unregisterExternalToken_WithInactiveToken() external {
        initializePantosHub();
        vm.expectRevert("PantosHub: token must be active");

        vm.prank(PANDAS_TOKEN_OWNER);
        pantosHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
    }

    function test_unregisterExternalToken_WithInactiveTokenBySuperCriticalOps()
        external
    {
        initializePantosHub();
        vm.expectRevert("PantosHub: token must be active");

        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
    }

    function test_unregisterExternalToken_WithInactiveTokenBySuperCriticalOpsWhenPaused()
        external
    {
        initializePantosHub();

        vm.prank(PAUSER);
        pantosHubProxy.pause();

        vm.expectRevert("PantosHub: token must be active");

        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
    }

    function test_unregisterExternalToken_ByNonTokenOwner() external {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
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

        vm.prank(PANDAS_TOKEN_OWNER);
        pantosHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
    }

    function test_unregisterExternalToken_WithInactiveExternalTokenBySuperCriticalOps()
        external
    {
        registerTokenBySuperCriticalOps();
        vm.expectRevert("PantosHub: external token must be active");

        vm.prank(SUPER_CRITICAL_OPS);
        pantosHubProxy.unregisterExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId)
        );
    }

    function test_unregisterExternalToken_WithInactiveExternalTokenBySuperCriticalOpsWhenPaused()
        external
    {
        registerTokenBySuperCriticalOps();
        vm.prank(PAUSER);
        pantosHubProxy.pause();
        vm.expectRevert("PantosHub: external token must be active");

        vm.prank(SUPER_CRITICAL_OPS);
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
        emit IPantosRegistry.ServiceNodeRegistered(
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL
        );
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
        assertEq(serviceNodeRecord.withdrawalTime, 0);
        assertEq(serviceNodes.length, 1);
        assertEq(serviceNodes[0], SERVICE_NODE_ADDRESS);
        checkServiceNodeIndices();
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
        emit IPantosRegistry.ServiceNodeUnregistered(
            SERVICE_NODE_ADDRESS,
            SERVICE_NODE_URL
        );
        vm.prank(SERVICE_NODE_ADDRESS);

        pantosHubProxy.unregisterServiceNode(SERVICE_NODE_ADDRESS);

        PantosTypes.ServiceNodeRecord memory serviceNodeRecord = pantosHubProxy
            .getServiceNodeRecord(SERVICE_NODE_ADDRESS);
        address[] memory serviceNodes = pantosHubProxy.getServiceNodes();
        assertFalse(serviceNodeRecord.active);
        assertEq(
            serviceNodeRecord.withdrawalTime,
            BLOCK_TIMESTAMP + SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD
        );
        assertEq(serviceNodeRecord.deposit, MINIMUM_SERVICE_NODE_DEPOSIT);
        assertEq(serviceNodes.length, 0);
        checkServiceNodeIndices();
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

    function test_registerServiceNode_unregisterServiceNode() external {
        address[] memory serviceNodeAddresses = new address[](3);
        serviceNodeAddresses[0] = SERVICE_NODE_ADDRESS;
        serviceNodeAddresses[1] = SERVICE_NODE_ADDRESS_1;
        serviceNodeAddresses[2] = SERVICE_NODE_ADDRESS_2;
        bool[] memory serviceNodeRegistered = new bool[](3);
        serviceNodeRegistered[0] = false;
        serviceNodeRegistered[1] = false;
        serviceNodeRegistered[2] = false;

        initializePantosHub();
        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateUnbondingPeriodServiceNodeDepositUpdate(0);
        vm.warp(BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY);
        pantosHubProxy.executeUnbondingPeriodServiceNodeDepositUpdate();
        mockIerc20_transfer(
            PANTOS_TOKEN_ADDRESS,
            SERVICE_NODE_WITHDRAWAL_ADDRESS,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            true
        );
        checkServiceNodeRegistrations(
            serviceNodeAddresses,
            serviceNodeRegistered
        );

        registerServiceNode(SERVICE_NODE_ADDRESS, SERVICE_NODE_URL);
        serviceNodeRegistered[0] = true;
        checkServiceNodeRegistrations(
            serviceNodeAddresses,
            serviceNodeRegistered
        );

        registerServiceNode(SERVICE_NODE_ADDRESS_1, SERVICE_NODE_URL_1);
        serviceNodeRegistered[1] = true;
        checkServiceNodeRegistrations(
            serviceNodeAddresses,
            serviceNodeRegistered
        );

        registerServiceNode(SERVICE_NODE_ADDRESS_2, SERVICE_NODE_URL_2);
        serviceNodeRegistered[2] = true;
        checkServiceNodeRegistrations(
            serviceNodeAddresses,
            serviceNodeRegistered
        );

        unregisterServiceNode(SERVICE_NODE_ADDRESS_1);
        serviceNodeRegistered[1] = false;
        checkServiceNodeRegistrations(
            serviceNodeAddresses,
            serviceNodeRegistered
        );

        vm.prank(SERVICE_NODE_WITHDRAWAL_ADDRESS);
        pantosHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS_1);

        registerServiceNode(SERVICE_NODE_ADDRESS_1, SERVICE_NODE_URL_1);
        serviceNodeRegistered[1] = true;
        checkServiceNodeRegistrations(
            serviceNodeAddresses,
            serviceNodeRegistered
        );

        unregisterServiceNode(SERVICE_NODE_ADDRESS);
        serviceNodeRegistered[0] = false;
        checkServiceNodeRegistrations(
            serviceNodeAddresses,
            serviceNodeRegistered
        );

        unregisterServiceNode(SERVICE_NODE_ADDRESS_2);
        serviceNodeRegistered[2] = false;
        checkServiceNodeRegistrations(
            serviceNodeAddresses,
            serviceNodeRegistered
        );

        vm.prank(SERVICE_NODE_WITHDRAWAL_ADDRESS);
        pantosHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);

        registerServiceNode(SERVICE_NODE_ADDRESS, SERVICE_NODE_URL);
        serviceNodeRegistered[0] = true;
        checkServiceNodeRegistrations(
            serviceNodeAddresses,
            serviceNodeRegistered
        );
    }

    function test_withdrawServiceNodeDeposit_ByWithdrawalAddress() external {
        registerServiceNode();
        unregisterServiceNode();
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
        assertEq(serviceNodeRecord.withdrawalTime, 0);
        assertEq(serviceNodeRecord.deposit, 0);
    }

    function test_withdrawServiceNodeDeposit_ByServiceNode() external {
        registerServiceNode();
        unregisterServiceNode();
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
        assertEq(serviceNodeRecord.withdrawalTime, 0);
        assertEq(serviceNodeRecord.deposit, 0);
    }

    function test_withdrawServiceNodeDeposit_WhenAlreadyWithdrawn() external {
        registerServiceNode();
        unregisterServiceNode();
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
        unregisterServiceNode();
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
        unregisterServiceNode();
        vm.prank(SERVICE_NODE_ADDRESS);
        vm.expectRevert("PantosHub: the unbonding period has not elapsed");

        pantosHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);
    }

    function test_withdrawServiceNodeDeposit_NoUnbondingPeriodBypass()
        external
    {
        mockIerc20_transfer(
            PANTOS_TOKEN_ADDRESS,
            SERVICE_NODE_WITHDRAWAL_ADDRESS,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            true
        );
        uint256 withdrawalTime;

        registerServiceNode();
        PantosTypes.ServiceNodeRecord memory storedStruct;
        storedStruct = loadPantosHubServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertTrue(storedStruct.active);
        assertEq(storedStruct.withdrawalTime, 0);

        // Service node is unregistered for the first time
        unregisterServiceNode();
        withdrawalTime =
            BLOCK_TIMESTAMP +
            SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD;
        storedStruct = loadPantosHubServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertFalse(storedStruct.active);
        assertEq(storedStruct.withdrawalTime, withdrawalTime);

        // Unbonding period has passed
        vm.warp(withdrawalTime);

        // Service node unregistration is canceled
        vm.prank(SERVICE_NODE_ADDRESS);
        pantosHubProxy.cancelServiceNodeUnregistration(SERVICE_NODE_ADDRESS);
        storedStruct = loadPantosHubServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertTrue(storedStruct.active);
        assertEq(storedStruct.withdrawalTime, 0);

        // Service node is unregistered immediately again
        unregisterServiceNode();
        withdrawalTime += SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD;
        storedStruct = loadPantosHubServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertFalse(storedStruct.active);
        assertEq(storedStruct.withdrawalTime, withdrawalTime);

        // Service node deposit cannot be withdrawn without the
        // unbonding period having passed again
        vm.expectRevert("PantosHub: the unbonding period has not elapsed");
        vm.prank(SERVICE_NODE_WITHDRAWAL_ADDRESS);
        pantosHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);
        storedStruct = loadPantosHubServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertFalse(storedStruct.active);
        assertEq(storedStruct.withdrawalTime, withdrawalTime);

        // Unbonding period has passed again
        vm.warp(withdrawalTime);

        // Service node deposit can be withdrawn now
        vm.prank(SERVICE_NODE_WITHDRAWAL_ADDRESS);
        pantosHubProxy.withdrawServiceNodeDeposit(SERVICE_NODE_ADDRESS);
        storedStruct = loadPantosHubServiceNodeRecord(SERVICE_NODE_ADDRESS);
        assertFalse(storedStruct.active);
        assertEq(storedStruct.withdrawalTime, 0);
    }

    function test_cancelServiceNodeUnregistration_ByWithdrawalAddress()
        external
    {
        registerServiceNode();
        unregisterServiceNode();
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
        assertEq(serviceNodeRecord.withdrawalTime, 0);
        assertEq(serviceNodes.length, 1);
        assertEq(serviceNodes[0], SERVICE_NODE_ADDRESS);
        checkServiceNodeIndices();
    }

    function test_cancelServiceNodeUnregistration_ByServiceNode() external {
        registerServiceNode();
        unregisterServiceNode();
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
        assertEq(serviceNodeRecord.withdrawalTime, 0);
        assertEq(serviceNodes.length, 1);
        assertEq(serviceNodes[0], SERVICE_NODE_ADDRESS);
        checkServiceNodeIndices();
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
        unregisterServiceNode();
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
        unregisterServiceNode();
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
        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateMinimumServiceNodeDepositUpdate(
            MINIMUM_SERVICE_NODE_DEPOSIT + 2
        );
        vm.warp(BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY);
        pantosHubProxy.executeMinimumServiceNodeDepositUpdate();
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
        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateMinimumServiceNodeDepositUpdate(
            MINIMUM_SERVICE_NODE_DEPOSIT - 1
        );
        vm.warp(BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY);
        pantosHubProxy.executeMinimumServiceNodeDepositUpdate();
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
        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateMinimumServiceNodeDepositUpdate(
            MINIMUM_SERVICE_NODE_DEPOSIT - 1
        );
        vm.warp(BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY);
        pantosHubProxy.executeMinimumServiceNodeDepositUpdate();
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
        unregisterServiceNode();
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
        emit IPantosRegistry.ServiceNodeUrlUpdated(
            SERVICE_NODE_ADDRESS,
            newSERVICE_NODE_URL
        );

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
        unregisterServiceNode();
        vm.expectRevert("PantosHub: service node must be active");

        pantosHubProxy.updateServiceNodeUrl(
            string.concat(SERVICE_NODE_URL, "extra")
        );
    }

    function test_updateServiceNodeUrl_WithSameUrlWhenNotActive() external {
        registerServiceNode();
        unregisterServiceNode();
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
            "",
            true,
            ""
        );
        vm.expectEmit();
        emit IPantosTransfer.TransferSucceeded(
            NEXT_TRANSFER_ID,
            transferRequest(),
            ""
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

    function test_transfer_PandasTokenFailure() external {
        registerToken();
        registerServiceNode();
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        mockPantosForwarder_verifyAndForwardTransfer(
            PANTOS_FORWARDER_ADDRESS,
            transferRequest(),
            "",
            false,
            PANDAS_TOKEN_FAILURE_DATA
        );
        vm.expectEmit();
        emit IPantosTransfer.TransferFailed(
            NEXT_TRANSFER_ID,
            transferRequest(),
            "",
            PANDAS_TOKEN_FAILURE_DATA
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

    function test_transferFrom() external {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        registerServiceNode();
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        mockPantosForwarder_verifyAndForwardTransferFrom(
            PANTOS_FORWARDER_ADDRESS,
            thisBlockchain.feeFactor,
            otherBlockchain.feeFactor,
            transferFromRequest(),
            "",
            true,
            ""
        );
        vm.expectEmit();
        emit IPantosTransfer.TransferFromSucceeded(
            NEXT_TRANSFER_ID,
            transferFromRequest(),
            ""
        );
        vm.prank(SERVICE_NODE_ADDRESS);
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

    function test_transferFrom_PandasTokenFailure() external {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        registerServiceNode();
        mockPandasToken_getPantosForwarder(
            PANDAS_TOKEN_ADDRESS,
            PANTOS_FORWARDER_ADDRESS
        );
        mockPantosForwarder_verifyAndForwardTransferFrom(
            PANTOS_FORWARDER_ADDRESS,
            thisBlockchain.feeFactor,
            otherBlockchain.feeFactor,
            transferFromRequest(),
            "",
            false,
            PANDAS_TOKEN_FAILURE_DATA
        );
        vm.expectEmit();
        emit IPantosTransfer.TransferFromFailed(
            NEXT_TRANSFER_ID,
            transferFromRequest(),
            "",
            PANDAS_TOKEN_FAILURE_DATA
        );
        vm.prank(SERVICE_NODE_ADDRESS);
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
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
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
        emit IPantosTransfer.TransferToSucceeded(
            NEXT_TRANSFER_ID,
            transferToRequest(),
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
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
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
        emit IPantosTransfer.TransferToSucceeded(
            NEXT_TRANSFER_ID,
            transferToRequest_,
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
        unregisterServiceNode();

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
        unregisterServiceNode();
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
        view
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
        vm.prank(MEDIUM_CRITICAL_OPS);
        pantosHubProxy.initiateMinimumServiceNodeDepositUpdate(
            MINIMUM_SERVICE_NODE_DEPOSIT + 1
        );
        vm.warp(BLOCK_TIMESTAMP + PARAMETER_UPDATE_DELAY);
        pantosHubProxy.executeMinimumServiceNodeDepositUpdate();
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
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
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
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
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
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
        registerServiceNode();
        vm.prank(SUPER_CRITICAL_OPS);
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
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
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
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
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
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
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
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);
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

    function test_getProtocolVersion() external {
        initializePantosHub();

        assertEq(PROTOCOL_VERSION, pantosHubProxy.getProtocolVersion());
    }

    function test_getNumberBlockchains() external view {
        assertEq(
            uint256(type(BlockchainId).max),
            pantosHubProxy.getNumberBlockchains()
        );
    }

    function test_getNumberActiveBlockchains() external view {
        assertEq(
            uint256(type(BlockchainId).max),
            pantosHubProxy.getNumberActiveBlockchains()
        );
    }

    function test_getCurrentBlockchainId() external view {
        assertEq(
            uint256(thisBlockchain.blockchainId),
            pantosHubProxy.getCurrentBlockchainId()
        );
    }

    function test_getBlockchainRecord() external view {
        PantosTypes.BlockchainRecord
            memory thisBlockchainRecord = pantosHubProxy.getBlockchainRecord(
                uint256(thisBlockchain.blockchainId)
            );

        assertEq(thisBlockchainRecord.name, thisBlockchain.name);
        assertTrue(thisBlockchainRecord.active);
    }

    function test_getCurrentMinimumServiceNodeDeposit() external view {
        assertEq(
            pantosHubProxy.getCurrentMinimumServiceNodeDeposit(),
            MINIMUM_SERVICE_NODE_DEPOSIT
        );
    }

    function test_getMinimumServiceNodeDeposit() external view {
        PantosTypes.UpdatableUint256
            memory minimumServiceNodeDeposit = pantosHubProxy
                .getMinimumServiceNodeDeposit();
        assertEq(
            minimumServiceNodeDeposit.currentValue,
            MINIMUM_SERVICE_NODE_DEPOSIT
        );
        assertEq(minimumServiceNodeDeposit.pendingValue, 0);
        assertEq(minimumServiceNodeDeposit.updateTime, 0);
    }

    function test_getCurrentUnbondingPeriodServiceNodeDeposit() external view {
        assertEq(
            pantosHubProxy.getCurrentUnbondingPeriodServiceNodeDeposit(),
            SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD
        );
    }

    function test_getUnbondingPeriodServiceNodeDeposit() external view {
        PantosTypes.UpdatableUint256
            memory unbondingPeriodServiceNodeDeposit = pantosHubProxy
                .getUnbondingPeriodServiceNodeDeposit();
        assertEq(
            unbondingPeriodServiceNodeDeposit.currentValue,
            SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD
        );
        assertEq(unbondingPeriodServiceNodeDeposit.pendingValue, 0);
        assertEq(unbondingPeriodServiceNodeDeposit.updateTime, 0);
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

    function test_getTokenRecord_WhenTokenNotRegistered() external view {
        PantosTypes.TokenRecord memory tokenRecord = pantosHubProxy
            .getTokenRecord(address(123));

        assertFalse(tokenRecord.active);
    }

    function test_getExternalTokenRecord_WhenExternalTokenRegistered()
        external
    {
        registerTokenAndExternalToken(PANDAS_TOKEN_OWNER);

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
        view
    {
        PantosTypes.ExternalTokenRecord
            memory externalTokenRecord = pantosHubProxy.getExternalTokenRecord(
                address(123),
                uint256(otherBlockchain.blockchainId)
            );

        assertFalse(externalTokenRecord.active);
        assertEq(externalTokenRecord.externalToken, "");
    }

    function test_getServiceNodes_WhenServiceNodeRegistered() external {
        registerServiceNode();

        address[] memory serviceNodes = pantosHubProxy.getServiceNodes();

        assertEq(serviceNodes.length, 1);
        assertEq(serviceNodes[0], SERVICE_NODE_ADDRESS);
    }

    function test_getServiceNodes_WhenServiceNodeNotRegistered()
        external
        view
    {
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
        assertEq(serviceNodeRecord.withdrawalTime, 0);
    }

    function test_getServiceNodeRecord_WhenServiceNodeNotRegistered()
        external
        view
    {
        PantosTypes.ServiceNodeRecord memory serviceNodeRecord = pantosHubProxy
            .getServiceNodeRecord(address(123));

        assertFalse(serviceNodeRecord.active);
        assertEq(serviceNodeRecord.url, "");
        assertEq(serviceNodeRecord.deposit, 0);
        assertEq(serviceNodeRecord.withdrawalAddress, ADDRESS_ZERO);
        assertEq(serviceNodeRecord.withdrawalTime, 0);
    }

    function test_getNextTransferId() external view {
        assertEq(pantosHubProxy.getNextTransferId(), 0);
    }

    function test_getCurrentValidatorFeeFactor() external view {
        assertEq(
            pantosHubProxy.getCurrentValidatorFeeFactor(
                uint256(thisBlockchain.blockchainId)
            ),
            thisBlockchain.feeFactor
        );
    }

    function test_getValidatorFeeFactor() external view {
        PantosTypes.UpdatableUint256 memory validatorFeeFactor = pantosHubProxy
            .getValidatorFeeFactor(uint256(thisBlockchain.blockchainId));
        assertEq(validatorFeeFactor.currentValue, thisBlockchain.feeFactor);
        assertEq(validatorFeeFactor.pendingValue, 0);
        assertEq(validatorFeeFactor.updateTime, 0);
    }

    function test_getCurrentParameterUpdateDelay() external view {
        assertEq(
            pantosHubProxy.getCurrentParameterUpdateDelay(),
            PARAMETER_UPDATE_DELAY
        );
    }

    function test_getParameterUpdateDelay() external view {
        PantosTypes.UpdatableUint256
            memory parameterUpdateDelay = pantosHubProxy
                .getParameterUpdateDelay();
        assertEq(parameterUpdateDelay.currentValue, PARAMETER_UPDATE_DELAY);
        assertEq(parameterUpdateDelay.pendingValue, 0);
        assertEq(parameterUpdateDelay.updateTime, 0);
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
        bytes memory signature,
        bool succeeded,
        bytes32 tokenData
    ) public {
        vm.mockCall(
            pantosForwarder,
            abi.encodeWithSelector(
                PantosForwarder.verifyAndForwardTransfer.selector,
                request,
                signature
            ),
            abi.encode(succeeded, tokenData)
        );
    }

    function mockPantosForwarder_verifyAndForwardTransferFrom(
        address pantosForwarder,
        uint256 sourceBlockchainFactor,
        uint256 destinationBlockchainFactor,
        PantosTypes.TransferFromRequest memory request,
        bytes memory signature,
        bool succeeded,
        bytes32 sourceTokenData
    ) public {
        vm.mockCall(
            pantosForwarder,
            abi.encodeWithSelector(
                PantosForwarder.verifyAndForwardTransferFrom.selector,
                sourceBlockchainFactor,
                destinationBlockchainFactor,
                request,
                signature
            ),
            abi.encode(succeeded, sourceTokenData)
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

    function registerToken(address tokenAddress, address tokenOwner) public {
        initializePantosHub();
        mockPandasToken_getOwner(tokenAddress, tokenOwner);
        mockPandasToken_getPantosForwarder(
            tokenAddress,
            PANTOS_FORWARDER_ADDRESS
        );
        vm.prank(tokenOwner);
        pantosHubProxy.registerToken(tokenAddress);
    }

    function registerToken() public {
        registerToken(PANDAS_TOKEN_ADDRESS, PANDAS_TOKEN_OWNER);
    }

    function registerTokenBySuperCriticalOps() public {
        registerToken(PANDAS_TOKEN_ADDRESS, SUPER_CRITICAL_OPS);
    }

    function registerTokenAndExternalToken(address tokenOwner) public {
        registerToken(PANDAS_TOKEN_ADDRESS, tokenOwner);
        vm.prank(tokenOwner);
        pantosHubProxy.registerExternalToken(
            PANDAS_TOKEN_ADDRESS,
            uint256(otherBlockchain.blockchainId),
            EXTERNAL_PANDAS_TOKEN_ADDRESS
        );
    }

    function registerServiceNode(
        address serviceNodeAddress,
        string memory serviceNodeUrl
    ) public {
        initializePantosHub();
        mockIerc20_transferFrom(
            PANTOS_TOKEN_ADDRESS,
            serviceNodeAddress,
            address(pantosHubProxy),
            MINIMUM_SERVICE_NODE_DEPOSIT,
            true
        );
        vm.prank(serviceNodeAddress);
        pantosHubProxy.registerServiceNode(
            serviceNodeAddress,
            serviceNodeUrl,
            MINIMUM_SERVICE_NODE_DEPOSIT,
            SERVICE_NODE_WITHDRAWAL_ADDRESS
        );
    }

    function registerServiceNode() public {
        registerServiceNode(SERVICE_NODE_ADDRESS, SERVICE_NODE_URL);
    }

    function unregisterServiceNode(address serviceNodeAddress) public {
        initializePantosHub();
        vm.prank(serviceNodeAddress);
        pantosHubProxy.unregisterServiceNode(serviceNodeAddress);
    }

    function unregisterServiceNode() public {
        unregisterServiceNode(SERVICE_NODE_ADDRESS);
    }

    function checkTokenIndices() private view {
        address[] memory tokenAddresses = loadPantosHubTokens();
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            address tokenAddress = tokenAddresses[i];
            assertEq(i, loadPantosHubTokenIndex(tokenAddress));
        }
    }

    function checkTokenRegistrations(
        address[] memory tokenAddresses,
        bool[] memory tokenRegistered
    ) private view {
        assertEq(tokenAddresses.length, tokenRegistered.length);
        address[] memory registeredTokenAddresses = loadPantosHubTokens();
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            address tokenAddress = tokenAddresses[i];
            PantosTypes.TokenRecord
                memory tokenRecord = loadPantosHubTokenRecord(tokenAddress);
            if (tokenRegistered[i]) {
                assertTrue(inArray(tokenAddress, registeredTokenAddresses));
                assertTrue(tokenRecord.active);
            } else {
                assertFalse(inArray(tokenAddress, registeredTokenAddresses));
                assertFalse(tokenRecord.active);
            }
        }
        checkTokenIndices();
    }

    function checkServiceNodeIndices() private view {
        address[] memory serviceNodeAddresses = loadPantosHubServiceNodes();
        for (uint256 i = 0; i < serviceNodeAddresses.length; i++) {
            address serviceNodeAddress = serviceNodeAddresses[i];
            assertEq(i, loadPantosHubServiceNodeIndex(serviceNodeAddress));
        }
    }

    function checkServiceNodeRegistrations(
        address[] memory serviceNodeAddresses,
        bool[] memory serviceNodeRegistered
    ) private view {
        assertEq(serviceNodeAddresses.length, serviceNodeRegistered.length);
        address[]
            memory registeredServiceNodeAddresses = loadPantosHubServiceNodes();
        for (uint256 i = 0; i < serviceNodeAddresses.length; i++) {
            address serviceNodeAddress = serviceNodeAddresses[i];
            PantosTypes.ServiceNodeRecord
                memory serviceNodeRecord = loadPantosHubServiceNodeRecord(
                    serviceNodeAddress
                );
            if (serviceNodeRegistered[i]) {
                assertTrue(
                    inArray(serviceNodeAddress, registeredServiceNodeAddresses)
                );
                assertTrue(serviceNodeRecord.active);
            } else {
                assertFalse(
                    inArray(serviceNodeAddress, registeredServiceNodeAddresses)
                );
                assertFalse(serviceNodeRecord.active);
            }
        }
        checkServiceNodeIndices();
    }

    function onlyRoleTest(
        address callee,
        bytes memory calldata_
    ) public override {
        vm.startPrank(address(111));
        bytes memory revertMessage = "PantosHub: caller doesn't have role";
        modifierTest(callee, calldata_, revertMessage);
    }
}
