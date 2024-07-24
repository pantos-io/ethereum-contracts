// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {console2} from "forge-std/console2.sol";
import {Vm} from "forge-std/Test.sol";

import {IPantosForwarder} from "../src/interfaces/IPantosForwarder.sol";
import {PantosForwarder} from "../src/PantosForwarder.sol";
import {PantosTypes} from "../src/interfaces/PantosTypes.sol";
import {IPantosRegistry} from "../src/interfaces/IPantosRegistry.sol";
import {PantosBaseToken} from "../src/PantosBaseToken.sol";

import {PantosBaseTest} from "./PantosBaseTest.t.sol";

contract PantosForwarderTest is PantosBaseTest {
    address public constant PANTOS_HUB_ADDRESS =
        address(uint160(uint256(keccak256("PantosHubAddress"))));
    address constant PANTOS_TOKEN_ADDRESS =
        address(uint160(uint256(keccak256("PantosTokenAddress"))));

    PantosForwarder public pantosForwarder;

    address[] _validators = [
        validatorAddress,
        validatorAddress2,
        validatorAddress3,
        validatorAddress4
    ];

    mapping(address => Vm.Wallet) _validatorWallets;

    uint256 public validatorCount;
    uint256[] public validatorCounts = [1, 2, 3, 4];

    function setUp() public {
        deployPantosForwarder();
        setUpValidatorWallets();
    }

    function setUpValidatorWallets() public {
        _validatorWallets[validatorAddress] = validatorWallet;
        _validatorWallets[validatorAddress2] = validatorWallet2;
        _validatorWallets[validatorAddress3] = validatorWallet3;
        _validatorWallets[validatorAddress4] = validatorWallet4;
    }

    function test_SetUpState() external {
        assertTrue(pantosForwarder.paused());
    }

    modifier parameterizedTest(uint256[] memory testSets) {
        uint256 length = testSets.length;
        for (uint256 i = 0; i < length; ) {
            validatorCount = testSets[i];
            setUp();
            i++;
            _;
        }
    }

    function test_pause_AfterInitialization()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();

        pantosForwarder.pause();

        assertTrue(pantosForwarder.paused());
    }

    function test_pause_WhenPaused() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosForwarder.pause.selector
        );

        whenNotPausedTest(address(pantosForwarder), calldata_);
    }

    function test_pause_ByNonOwner()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosForwarder.pause.selector
        );

        onlyOwnerTest(address(pantosForwarder), calldata_);
    }

    function test_unpause_AfterDeploy()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();

        assertFalse(pantosForwarder.paused());
    }

    function test_unpause_WhenNotPaused()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosForwarder.unpause.selector
        );

        whenPausedTest(address(pantosForwarder), calldata_);
    }

    function test_unpause_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosForwarder.unpause.selector
        );

        onlyOwnerTest(address(pantosForwarder), calldata_);
    }

    function test_unpause_WithNoPantosHubSet() external {
        vm.expectRevert("PantosForwarder: PantosHub has not been set");

        pantosForwarder.unpause();
    }

    function test_unpause_WithNoPantosTokenSet() external {
        pantosForwarder.setPantosHub(PANTOS_HUB_ADDRESS);
        vm.expectRevert("PantosForwarder: PantosToken has not been set");

        pantosForwarder.unpause();
    }

    function test_unpause_WithNoValidatorSet() external {
        pantosForwarder.setPantosHub(PANTOS_HUB_ADDRESS);
        pantosForwarder.setPantosToken(PANTOS_TOKEN_ADDRESS);
        vm.expectRevert("PantosForwarder: not enough validator nodes added");

        pantosForwarder.unpause();
    }

    function test_unpause_WithLessThanMinValidatorSet() external {
        pantosForwarder.setPantosHub(PANTOS_HUB_ADDRESS);
        pantosForwarder.setPantosToken(PANTOS_TOKEN_ADDRESS);
        pantosForwarder.setMinimumValidatorNodeSignatures(3);
        pantosForwarder.addValidatorNode(validatorAddress);
        pantosForwarder.addValidatorNode(validatorAddress2);
        vm.expectRevert("PantosForwarder: not enough validator nodes added");

        pantosForwarder.unpause();
    }

    function test_setPantosHub() external {
        vm.expectEmit(address(pantosForwarder));
        emit IPantosForwarder.PantosHubSet(PANTOS_HUB_ADDRESS);

        pantosForwarder.setPantosHub(PANTOS_HUB_ADDRESS);

        assertEq(pantosForwarder.getPantosHub(), PANTOS_HUB_ADDRESS);
    }

    function test_setPantosHubMultipleTimes() external {
        for (uint256 i = 0; i < 10; i++) {
            vm.expectEmit(address(pantosForwarder));
            emit IPantosForwarder.PantosHubSet(PANTOS_HUB_ADDRESS);

            pantosForwarder.setPantosHub(PANTOS_HUB_ADDRESS);

            assertEq(pantosForwarder.getPantosHub(), PANTOS_HUB_ADDRESS);
        }
    }

    function test_setPantosHub_WhenNotPaused()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosForwarder.setPantosHub.selector,
            PANTOS_HUB_ADDRESS
        );

        whenPausedTest(address(pantosForwarder), calldata_);
    }

    function test_setPantosHub_ByNonOwner() external {
        // pantosForwarder.pause();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosForwarder.setPantosHub.selector,
            PANTOS_HUB_ADDRESS
        );

        onlyOwnerTest(address(pantosForwarder), calldata_);
    }

    function test_setPantosHub_WithAddress0() external {
        vm.expectRevert(
            "PantosForwarder: PantosHub must not be the zero account"
        );

        pantosForwarder.setPantosHub(ADDRESS_ZERO);
    }

    function test_setPantosToken() external {
        vm.expectEmit(address(pantosForwarder));
        emit IPantosForwarder.PantosTokenSet(PANTOS_TOKEN_ADDRESS);

        pantosForwarder.setPantosToken(PANTOS_TOKEN_ADDRESS);

        assertEq(pantosForwarder.getPantosToken(), PANTOS_TOKEN_ADDRESS);
    }

    function test_setPantosToken_WhenNotPaused()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosForwarder.setPantosToken.selector,
            PANTOS_TOKEN_ADDRESS
        );

        whenPausedTest(address(pantosForwarder), calldata_);
    }

    function test_setPantosToken_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosForwarder.setPantosToken.selector,
            PANTOS_TOKEN_ADDRESS
        );

        onlyOwnerTest(address(pantosForwarder), calldata_);
    }

    function test_setPantosToken_WithAddress0() external {
        vm.expectRevert(
            "PantosForwarder: PantosToken must not be the zero account"
        );

        pantosForwarder.setPantosToken(ADDRESS_ZERO);
    }

    function test_setMinimumValidatorNodeSignatures() external {
        vm.expectEmit(address(pantosForwarder));
        emit IPantosForwarder.MinimumValidatorNodeSignaturesUpdated(1);

        pantosForwarder.setMinimumValidatorNodeSignatures(1);

        assertEq(pantosForwarder.getMinimumValidatorNodeSignatures(), 1);
    }

    function test_setMinimumValidatorNodeSignatures_With0() external {
        vm.expectRevert("PantosForwarder: at least one signature required");

        pantosForwarder.setMinimumValidatorNodeSignatures(0);

        assertNotEq(pantosForwarder.getMinimumValidatorNodeSignatures(), 0);
    }

    function test_setMinimumValidatorNodeSignatures_WhenNotPaused()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosForwarder.setMinimumValidatorNodeSignatures.selector,
            validatorCount
        );

        whenPausedTest(address(pantosForwarder), calldata_);
    }

    function test_setMinimumValidatorNodeSignatures_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosForwarder.setMinimumValidatorNodeSignatures.selector,
            1
        );

        onlyOwnerTest(address(pantosForwarder), calldata_);
    }

    function test_addValidatorNode_Single() external {
        pantosForwarder.setPantosHub(PANTOS_HUB_ADDRESS);
        pantosForwarder.setPantosToken(PANTOS_TOKEN_ADDRESS);
        pantosForwarder.setMinimumValidatorNodeSignatures(1);
        vm.expectEmit(address(pantosForwarder));
        emit IPantosForwarder.ValidatorNodeAdded(validatorAddress);

        pantosForwarder.addValidatorNode(validatorAddress);

        address[] memory actualValidatorNodes = pantosForwarder
            .getValidatorNodes();
        assertEq(actualValidatorNodes[0], validatorAddress);
    }

    function test_addValidatorNode_Multiple()
        external
        parameterizedTest(validatorCounts)
    {
        address[] memory validatorNodes = getValidatorNodeAddresses();

        initializePantosForwarder();

        address[] memory actualValidatorNodes = pantosForwarder
            .getValidatorNodes();
        for (uint i = 0; i < validatorNodes.length; i++)
            assertEq(actualValidatorNodes[i], validatorNodes[i]);
        assertSortedAscending(actualValidatorNodes);
    }

    function test_addValidatorNode_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosForwarder.addValidatorNode.selector,
            validatorAddress
        );

        onlyOwnerTest(address(pantosForwarder), calldata_);
    }

    function test_addValidatorNode_WhenNotPaused() external {
        pantosForwarder.setPantosHub(PANTOS_HUB_ADDRESS);
        pantosForwarder.setPantosToken(PANTOS_TOKEN_ADDRESS);
        pantosForwarder.setMinimumValidatorNodeSignatures(1);
        pantosForwarder.addValidatorNode(validatorAddress);
        pantosForwarder.unpause();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosForwarder.addValidatorNode.selector,
            validatorAddress2
        );

        whenPausedTest(address(pantosForwarder), calldata_);
    }

    function test_addValidatorNode_0Address() external {
        pantosForwarder.setPantosHub(PANTOS_HUB_ADDRESS);
        pantosForwarder.setPantosToken(PANTOS_TOKEN_ADDRESS);
        pantosForwarder.setMinimumValidatorNodeSignatures(1);
        vm.expectRevert(
            "PantosForwarder: validator node address must not be zero"
        );

        pantosForwarder.addValidatorNode(ADDRESS_ZERO);
    }

    function test_addValidatorNode_SameAddressTwice() external {
        pantosForwarder.setPantosHub(PANTOS_HUB_ADDRESS);
        pantosForwarder.setPantosToken(PANTOS_TOKEN_ADDRESS);
        pantosForwarder.setMinimumValidatorNodeSignatures(3);
        pantosForwarder.addValidatorNode(validatorAddress);
        vm.expectRevert("PantosForwarder: validator node already added");

        pantosForwarder.addValidatorNode(validatorAddress);
    }

    function test_addValidatorNode_SameAddressesTwice()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        pantosForwarder.pause();
        address[] memory validatorNodeAddresses = getValidatorNodeAddresses();

        for (uint i = 0; i < validatorNodeAddresses.length; i++) {
            vm.expectRevert("PantosForwarder: validator node already added");
            pantosForwarder.addValidatorNode(validatorNodeAddresses[i]);
        }
    }

    function test_removeValidatorNode()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        pantosForwarder.pause();
        address[] memory validatorNodeAddresses = getValidatorNodeAddresses();
        address validatorNodeAddress = validatorNodeAddresses[
            validatorNodeAddresses.length - 1
        ];
        vm.expectEmit(address(pantosForwarder));
        emit IPantosForwarder.ValidatorNodeRemoved(validatorNodeAddress);

        pantosForwarder.removeValidatorNode(validatorNodeAddress);

        address[] memory finalValidatorNodeAddresses = pantosForwarder
            .getValidatorNodes();
        assertEq(
            finalValidatorNodeAddresses.length,
            validatorNodeAddresses.length - 1
        );
        if (finalValidatorNodeAddresses.length > 0) {
            for (uint i; i < finalValidatorNodeAddresses.length - 1; i++) {
                assertEq(
                    finalValidatorNodeAddresses[i],
                    validatorNodeAddresses[i]
                );
            }
        }
        assertSortedAscending(finalValidatorNodeAddresses);
    }

    function test_removeValidatorNode_RemoveAll()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        pantosForwarder.pause();
        address[] memory validatorNodeAddresses = getValidatorNodeAddresses();

        for (uint i; i < validatorNodeAddresses.length; i++) {
            vm.expectEmit(address(pantosForwarder));
            emit IPantosForwarder.ValidatorNodeRemoved(
                validatorNodeAddresses[i]
            );
            pantosForwarder.removeValidatorNode(validatorNodeAddresses[i]);
        }

        address[] memory finalValidatorNodeAddresses = pantosForwarder
            .getValidatorNodes();
        assertEq(finalValidatorNodeAddresses.length, 0);
    }

    function test_removeValidatorNode_RemoveAllAndAddAgain()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        pantosForwarder.pause();
        address[] memory validatorNodeAddresses = getValidatorNodeAddresses();
        for (uint i; i < validatorNodeAddresses.length; i++) {
            vm.expectEmit(address(pantosForwarder));
            emit IPantosForwarder.ValidatorNodeRemoved(
                validatorNodeAddresses[i]
            );
            pantosForwarder.removeValidatorNode(validatorNodeAddresses[i]);
        }
        address[] memory finalValidatorNodeAddresses = pantosForwarder
            .getValidatorNodes();
        assertEq(finalValidatorNodeAddresses.length, 0);

        for (uint i = 0; i < validatorNodeAddresses.length; i++) {
            vm.expectEmit(address(pantosForwarder));
            emit IPantosForwarder.ValidatorNodeAdded(
                validatorNodeAddresses[i]
            );
            pantosForwarder.addValidatorNode(validatorNodeAddresses[i]);
        }

        finalValidatorNodeAddresses = pantosForwarder.getValidatorNodes();
        assertEq(
            finalValidatorNodeAddresses.length,
            validatorNodeAddresses.length
        );
        assertSortedAscending(finalValidatorNodeAddresses);
    }

    function test_removeValidatorNode_0Address()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        pantosForwarder.pause();
        vm.expectRevert(
            "PantosForwarder: validator node address must not be zero"
        );

        pantosForwarder.removeValidatorNode(ADDRESS_ZERO);
    }

    function test_removeValidatorNode_NotExisting()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        pantosForwarder.pause();
        vm.expectRevert("PantosForwarder: validator node not added");

        pantosForwarder.removeValidatorNode(testWallet.addr);
    }

    function test_removeValidatorNode_ByNonOwner()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        pantosForwarder.pause();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosForwarder.removeValidatorNode.selector,
            validatorAddress
        );

        onlyOwnerTest(address(pantosForwarder), calldata_);
    }

    function test_removeValidatorNode_WhenNotPaused()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosForwarder.removeValidatorNode.selector,
            validatorAddress
        );

        whenPausedTest(address(pantosForwarder), calldata_);
    }

    function test_verifyAndForwardTransfer()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferRequest memory request = transferRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        setupMockAndExpectFor_verifyAndForwardTransfer(request);
        vm.prank(PANTOS_HUB_ADDRESS);

        pantosForwarder.verifyAndForwardTransfer(request, signature);
    }

    function test_verifyAndForwardTransfer_NotByPantosHub()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferRequest memory request = transferRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);

        bytes memory calldata_ = abi.encodeWithSelector(
            PantosForwarder.verifyAndForwardTransfer.selector,
            request,
            signature
        );

        onlyByPantosHubTest(address(pantosForwarder), calldata_);
    }

    function test_verifyAndForwardTransfer_ReusingNonce()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferRequest memory request = transferRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        setupMockAndExpectFor_verifyAndForwardTransfer(request);

        vm.startPrank(PANTOS_HUB_ADDRESS);
        pantosForwarder.verifyAndForwardTransfer(request, signature);
        vm.expectRevert("PantosForwarder: sender nonce invalid");

        pantosForwarder.verifyAndForwardTransfer(request, signature);
    }

    function test_verifyAndForwardTransfer_SameNonceDifferentSender()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferRequest memory request = transferRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        setupMockAndExpectFor_verifyAndForwardTransfer(request);

        vm.startPrank(PANTOS_HUB_ADDRESS);
        pantosForwarder.verifyAndForwardTransfer(request, signature);

        request.sender = transferSender2;
        digest = getDigest(request);
        signature = sign(testWallet2, digest);
        setupMockAndExpectFor_verifyAndForwardTransfer(request);
        pantosForwarder.verifyAndForwardTransfer(request, signature);
    }

    function test_verifyAndForwardTransfer_SameSenderDifferentNonce()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferRequest memory request = transferRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        setupMockAndExpectFor_verifyAndForwardTransfer(request);

        vm.startPrank(PANTOS_HUB_ADDRESS);
        pantosForwarder.verifyAndForwardTransfer(request, signature);

        request.nonce = 99;
        digest = getDigest(request);
        signature = sign(testWallet, digest);
        setupMockAndExpectFor_verifyAndForwardTransfer(request);
        pantosForwarder.verifyAndForwardTransfer(request, signature);
    }

    function test_verifyAndForwardTransfer_ValidUntilExpired()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferRequest memory request = transferRequest();
        request.validUntil = block.timestamp - 1;
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        vm.startPrank(PANTOS_HUB_ADDRESS);
        vm.expectRevert("PantosForwarder: validity period has expired");

        pantosForwarder.verifyAndForwardTransfer(request, signature);
    }

    function test_verifyAndForwardTransfer_ValidSignatureNotBySender()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferRequest memory request = transferRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet2, digest);

        mockAndExpectPantosHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        vm.startPrank(PANTOS_HUB_ADDRESS);
        string memory revertMsg = string.concat(
            "PantosForwarder: invalid signature by ",
            Strings.toHexString(transferSender)
        );
        vm.expectRevert(bytes(revertMsg));

        pantosForwarder.verifyAndForwardTransfer(request, signature);
    }

    function test_verifyAndForwardTransferFrom()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferFromRequest memory request = transferFromRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        uint256 sourceBlockchainFactor = 2;
        uint256 destinationBlockchainFactor = 2;
        setupMockAndExpectFor_verifyAndForwardTransferFrom(
            request,
            sourceBlockchainFactor,
            destinationBlockchainFactor
        );
        vm.prank(PANTOS_HUB_ADDRESS);

        pantosForwarder.verifyAndForwardTransferFrom(
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            request,
            signature
        );
    }

    function test_verifyAndForwardTransferFrom_NotByPantosHub()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferFromRequest memory request = transferFromRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        uint256 sourceBlockchainFactor = 2;
        uint256 destinationBlockchainFactor = 2;

        bytes memory calldata_ = abi.encodeWithSelector(
            PantosForwarder.verifyAndForwardTransferFrom.selector,
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            request,
            signature
        );

        onlyByPantosHubTest(address(pantosForwarder), calldata_);
    }

    function test_verifyAndForwardTransferFrom_ReusingNonce()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferFromRequest memory request = transferFromRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        uint256 sourceBlockchainFactor = 2;
        uint256 destinationBlockchainFactor = 2;
        setupMockAndExpectFor_verifyAndForwardTransferFrom(
            request,
            sourceBlockchainFactor,
            destinationBlockchainFactor
        );
        vm.startPrank(PANTOS_HUB_ADDRESS);
        pantosForwarder.verifyAndForwardTransferFrom(
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            request,
            signature
        );
        vm.expectRevert("PantosForwarder: sender nonce invalid");

        pantosForwarder.verifyAndForwardTransferFrom(
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            request,
            signature
        );
    }

    function test_verifyAndForwardTransferFrom_SameNonceDifferentSender()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferFromRequest memory request = transferFromRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        uint256 sourceBlockchainFactor = 2;
        uint256 destinationBlockchainFactor = 2;
        setupMockAndExpectFor_verifyAndForwardTransferFrom(
            request,
            sourceBlockchainFactor,
            destinationBlockchainFactor
        );
        vm.startPrank(PANTOS_HUB_ADDRESS);
        pantosForwarder.verifyAndForwardTransferFrom(
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            request,
            signature
        );

        request.sender = transferSender2;
        digest = getDigest(request);
        signature = sign(testWallet2, digest);
        setupMockAndExpectFor_verifyAndForwardTransferFrom(
            request,
            sourceBlockchainFactor,
            destinationBlockchainFactor
        );

        pantosForwarder.verifyAndForwardTransferFrom(
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            request,
            signature
        );
    }

    function test_verifyAndForwardTransferFrom_SameSenderDifferentNonce()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferFromRequest memory request = transferFromRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        uint256 sourceBlockchainFactor = 2;
        uint256 destinationBlockchainFactor = 2;
        setupMockAndExpectFor_verifyAndForwardTransferFrom(
            request,
            sourceBlockchainFactor,
            destinationBlockchainFactor
        );
        vm.startPrank(PANTOS_HUB_ADDRESS);
        pantosForwarder.verifyAndForwardTransferFrom(
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            request,
            signature
        );

        request.nonce = 99;
        digest = getDigest(request);
        signature = sign(testWallet, digest);
        setupMockAndExpectFor_verifyAndForwardTransferFrom(
            request,
            sourceBlockchainFactor,
            destinationBlockchainFactor
        );

        pantosForwarder.verifyAndForwardTransferFrom(
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            request,
            signature
        );
    }

    function test_verifyAndForwardTransferFrom_ValidUntilExpired()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferFromRequest memory request = transferFromRequest();
        request.validUntil = block.timestamp - 1;
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        uint256 sourceBlockchainFactor = 2;
        uint256 destinationBlockchainFactor = 2;

        vm.startPrank(PANTOS_HUB_ADDRESS);
        vm.expectRevert("PantosForwarder: validity period has expired");

        pantosForwarder.verifyAndForwardTransferFrom(
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            request,
            signature
        );
    }

    function test_verifyAndForwardTransferFrom_ValidSignatureNotBySender()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferFromRequest memory request = transferFromRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet2, digest);
        uint256 sourceBlockchainFactor = 2;
        uint256 destinationBlockchainFactor = 2;
        mockAndExpectPantosHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        vm.startPrank(PANTOS_HUB_ADDRESS);
        string memory revertMsg = string.concat(
            "PantosForwarder: invalid signature by ",
            Strings.toHexString(transferSender)
        );
        vm.expectRevert(bytes(revertMsg));

        pantosForwarder.verifyAndForwardTransferFrom(
            sourceBlockchainFactor,
            destinationBlockchainFactor,
            request,
            signature
        );
    }

    function test_verifyAndForwardTransferTo()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferToRequest memory request = transferToRequest();
        bytes32 digest = getDigest(request);
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = signByValidators(digest);
        setupMockAndExpectFor_verifyAndForwardTransferTo(request);
        vm.prank(PANTOS_HUB_ADDRESS);

        pantosForwarder.verifyAndForwardTransferTo(
            request,
            signerAddresses,
            signatures
        );
    }

    function test_verifyAndForwardTransferTo_NotByPantosHub()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferToRequest memory request = transferToRequest();
        bytes32 digest = getDigest(request);
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = signByValidators(digest);

        bytes memory calldata_ = abi.encodeWithSelector(
            PantosForwarder.verifyAndForwardTransferTo.selector,
            request,
            signerAddresses,
            signatures
        );

        onlyByPantosHubTest(address(pantosForwarder), calldata_);
    }

    function test_verifyAndForwardTransferTo_ReusingNonce()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferToRequest memory request = transferToRequest();
        bytes32 digest = getDigest(request);
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = signByValidators(digest);
        setupMockAndExpectFor_verifyAndForwardTransferTo(request);
        vm.startPrank(PANTOS_HUB_ADDRESS);
        pantosForwarder.verifyAndForwardTransferTo(
            request,
            signerAddresses,
            signatures
        );
        vm.expectRevert("PantosForwarder: validator node nonce invalid");
        pantosForwarder.verifyAndForwardTransferTo(
            request,
            signerAddresses,
            signatures
        );
    }

    function test_verifyAndForwardTransferTo_DifferentNonce()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferToRequest memory request = transferToRequest();
        bytes32 digest = getDigest(request);
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = signByValidators(digest);
        setupMockAndExpectFor_verifyAndForwardTransferTo(request);
        vm.startPrank(PANTOS_HUB_ADDRESS);
        pantosForwarder.verifyAndForwardTransferTo(
            request,
            signerAddresses,
            signatures
        );

        request.nonce = 99;
        digest = getDigest(request);
        signatures = signByValidators(digest);
        setupMockAndExpectFor_verifyAndForwardTransferTo(request);
        pantosForwarder.verifyAndForwardTransferTo(
            request,
            signerAddresses,
            signatures
        );
    }

    function test_verifyAndForwardTransferTo_SignedByOneNonValidator()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferToRequest memory request = transferToRequest();
        bytes32 digest = getDigest(request);
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = signByValidatorsAndOneNonValidator(digest);
        mockAndExpectPantosHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        vm.startPrank(PANTOS_HUB_ADDRESS);
        string memory revertMsg = string.concat(
            "PantosForwarder: invalid signature by ",
            Strings.toHexString(signerAddresses[signerAddresses.length - 1])
        );
        vm.expectRevert(bytes(revertMsg));
        pantosForwarder.verifyAndForwardTransferTo(
            request,
            signerAddresses,
            signatures
        );
    }

    function test_verifyAndForwardTransferTo_OneSignerAndSignatureMissing()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferToRequest memory request = transferToRequest();
        bytes32 digest = getDigest(request);
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = signByValidators(digest);
        mockAndExpectPantosHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        address[] memory signerAddressesLess = new address[](
            signerAddresses.length - 1
        );
        bytes[] memory signaturesLess = new bytes[](signatures.length - 1);
        for (uint i = 0; i < signaturesLess.length; i++) {
            signerAddressesLess[i] = signerAddresses[i];
            signatures[i] = signaturesLess[i];
        }

        vm.startPrank(PANTOS_HUB_ADDRESS);
        vm.expectRevert("PantosForwarder: insufficient number of signatures");
        pantosForwarder.verifyAndForwardTransferTo(
            request,
            signerAddressesLess,
            signaturesLess
        );
    }

    function test_verifyAndForwardTransferTo_OneSignatureMissing()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferToRequest memory request = transferToRequest();
        bytes32 digest = getDigest(request);
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = signByValidators(digest);
        mockAndExpectPantosHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        bytes[] memory signaturesLess = new bytes[](signatures.length - 1);
        for (uint i = 0; i < signaturesLess.length; i++) {
            signatures[i] = signaturesLess[i];
        }

        vm.startPrank(PANTOS_HUB_ADDRESS);
        vm.expectRevert(
            "PantosForwarder: numbers of signers and signatures must match"
        );
        pantosForwarder.verifyAndForwardTransferTo(
            request,
            signerAddresses,
            signaturesLess
        );
    }

    function test_verifyAndForwardTransferTo_OneSignerMissing()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferToRequest memory request = transferToRequest();
        bytes32 digest = getDigest(request);
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = signByValidators(digest);
        mockAndExpectPantosHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        address[] memory signerAddressesLess = new address[](
            signerAddresses.length - 1
        );
        for (uint i = 0; i < signerAddressesLess.length; i++) {
            signerAddressesLess[i] = signerAddresses[i];
        }

        vm.startPrank(PANTOS_HUB_ADDRESS);
        vm.expectRevert(
            "PantosForwarder: numbers of signers and signatures must match"
        );
        pantosForwarder.verifyAndForwardTransferTo(
            request,
            signerAddressesLess,
            signatures
        );
    }

    function test_verifyTransfer()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferRequest memory request = transferRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        mockAndExpectPantosHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        vm.prank(PANTOS_HUB_ADDRESS);

        pantosForwarder.verifyTransfer(request, signature);
    }

    function test_verifyTransferNotByPantosHub()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferRequest memory request = transferRequest();
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);

        bytes memory calldata_ = abi.encodeWithSelector(
            PantosForwarder.verifyTransfer.selector,
            request,
            signature
        );

        onlyByPantosHubTest(address(pantosForwarder), calldata_);
    }

    function test_verifyTransferZeroAmount()
        external
        parameterizedTest(validatorCounts)
    {
        initializePantosForwarder();
        PantosTypes.TransferRequest memory request = transferRequest();
        request.amount = 0;
        bytes32 digest = getDigest(request);
        bytes memory signature = sign(testWallet, digest);
        vm.prank(PANTOS_HUB_ADDRESS);
        vm.expectRevert("PantosForwarder: amount must be greater than 0");

        pantosForwarder.verifyTransfer(request, signature);
    }

    //  All the mock utils here
    function mockAndExpectPantosHub_getPrimaryValidatorNode() public {
        vm.mockCall(
            PANTOS_HUB_ADDRESS,
            abi.encodeWithSelector(
                IPantosRegistry.getPrimaryValidatorNode.selector
            ),
            abi.encode(validatorAddress)
        );

        vm.expectCall(
            PANTOS_HUB_ADDRESS,
            abi.encodeWithSelector(
                IPantosRegistry.getPrimaryValidatorNode.selector
            )
        );
    }

    function mockAndExpectPantosHub_getCurrentBlockchainId(
        BlockchainId blockchainId
    ) public {
        vm.mockCall(
            PANTOS_HUB_ADDRESS,
            abi.encodeWithSelector(
                IPantosRegistry.getCurrentBlockchainId.selector
            ),
            abi.encode(uint256(blockchainId))
        );

        vm.expectCall(
            PANTOS_HUB_ADDRESS,
            abi.encodeWithSelector(
                IPantosRegistry.getCurrentBlockchainId.selector
            )
        );
    }

    function mockAndExpectPantosBaseToken_pantosTransfer(
        address tokenAddress,
        address sender,
        address recipient,
        uint256 amount
    ) public {
        bytes memory abiEncodedWithSelector = abi.encodeWithSelector(
            PantosBaseToken.pantosTransfer.selector,
            sender,
            recipient,
            amount
        );
        vm.mockCall(tokenAddress, abiEncodedWithSelector, abi.encode());
        vm.expectCall(tokenAddress, abiEncodedWithSelector);
    }

    function mockAndExpectPantosBaseToken_pantosTransferFrom(
        PantosTypes.TransferFromRequest memory request
    ) public {
        bytes memory abiEncodedWithSelector = abi.encodeWithSelector(
            PantosBaseToken.pantosTransferFrom.selector,
            request.sender,
            request.amount
        );
        vm.mockCall(request.sourceToken, abiEncodedWithSelector, abi.encode());
        vm.expectCall(request.sourceToken, abiEncodedWithSelector);
    }

    function mockAndExpectPantosBaseToken_pantosTransferTo(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) public {
        bytes memory abiEncodedWithSelector = abi.encodeWithSelector(
            PantosBaseToken.pantosTransferTo.selector,
            recipient,
            amount
        );
        vm.mockCall(tokenAddress, abiEncodedWithSelector, abi.encode());
        vm.expectCall(tokenAddress, abiEncodedWithSelector);
    }

    function setupMockAndExpectFor_verifyAndForwardTransfer(
        PantosTypes.TransferRequest memory request
    ) public {
        mockAndExpectPantosHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        mockAndExpectPantosBaseToken_pantosTransfer(
            request.token,
            request.sender,
            request.recipient,
            request.amount
        );
        mockAndExpectPantosBaseToken_pantosTransfer(
            PANTOS_TOKEN_ADDRESS,
            request.sender,
            request.serviceNode,
            request.fee
        );
    }

    function setupMockAndExpectFor_verifyAndForwardTransferFrom(
        PantosTypes.TransferFromRequest memory request,
        uint256 sourceBlockchainFactor,
        uint256 destinationBlockchainFactor
    ) public {
        mockAndExpectPantosHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        mockAndExpectPantosBaseToken_pantosTransferFrom(request);
        uint256 totalFactor = sourceBlockchainFactor +
            destinationBlockchainFactor;
        uint256 serviceNodeFee = (sourceBlockchainFactor * request.fee) /
            totalFactor;
        mockAndExpectPantosBaseToken_pantosTransfer(
            PANTOS_TOKEN_ADDRESS,
            request.sender,
            request.serviceNode,
            serviceNodeFee
        );
        uint256 validatorFee = request.fee - serviceNodeFee;
        mockAndExpectPantosBaseToken_pantosTransfer(
            PANTOS_TOKEN_ADDRESS,
            request.sender,
            validatorAddress,
            validatorFee
        );
        mockAndExpectPantosHub_getPrimaryValidatorNode();
    }

    function setupMockAndExpectFor_verifyAndForwardTransferTo(
        PantosTypes.TransferToRequest memory request
    ) public {
        mockAndExpectPantosHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        mockAndExpectPantosBaseToken_pantosTransferTo(
            request.destinationToken,
            request.recipient,
            request.amount
        );
    }

    // Mocks end here

    function deployPantosForwarder() public {
        pantosForwarder = new PantosForwarder();
    }

    function getValidatorNodeAddresses()
        public
        view
        returns (address[] memory)
    {
        address[] memory validatorNodeAddresses = new address[](
            validatorCount
        );
        for (uint i = 0; i < validatorNodeAddresses.length; i++) {
            validatorNodeAddresses[i] = _validators[i];
        }
        return validatorNodeAddresses;
    }

    function initializePantosForwarder() public {
        address[] memory validatorNodeAddresses = getValidatorNodeAddresses();
        initializePantosForwarder(validatorNodeAddresses);
    }

    function initializePantosForwarder(
        address[] memory validatorNodeAddresses
    ) public {
        // Set the hub, PAN token, and validator addresses
        pantosForwarder.setPantosHub(PANTOS_HUB_ADDRESS);
        pantosForwarder.setPantosToken(PANTOS_TOKEN_ADDRESS);
        pantosForwarder.setMinimumValidatorNodeSignatures(
            validatorNodeAddresses.length
        );
        for (uint i = 0; i < validatorNodeAddresses.length; i++) {
            vm.expectEmit(address(pantosForwarder));
            emit IPantosForwarder.ValidatorNodeAdded(
                validatorNodeAddresses[i]
            );
            pantosForwarder.addValidatorNode(validatorNodeAddresses[i]);
        }

        // Unpause the forwarder contract after initialization
        pantosForwarder.unpause();
    }

    function onlyByPantosHubTest(
        address callee,
        bytes memory calldata_
    ) public {
        string
            memory revertMessage = "PantosForwarder: caller is not the PantosHub";
        modifierTest(callee, calldata_, revertMessage);
    }

    function sign(
        Vm.Wallet memory signer,
        bytes32 digest
    ) public returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer, digest);
        return abi.encodePacked(r, s, v);
    }

    function signByValidators(bytes32 digest) public returns (bytes[] memory) {
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = new bytes[](signerAddresses.length);

        for (uint256 i = 0; i < signerAddresses.length; i++) {
            signatures[i] = sign(
                _validatorWallets[signerAddresses[i]],
                digest
            );
        }
        return signatures;
    }

    function signByValidatorsAndOneNonValidator(
        bytes32 digest
    ) public returns (bytes[] memory) {
        address[] memory signerAddresses = getValidatorNodeAddresses();
        bytes[] memory signatures = signByValidators(digest);
        signatures[signerAddresses.length - 1] = sign(testWallet, digest);
        return signatures;
    }

    function getDigest(
        PantosTypes.TransferRequest memory request
    ) public view returns (bytes32) {
        return
            MessageHashUtils.toEthSignedMessageHash(
                keccak256(
                    abi.encodePacked(
                        uint256(thisBlockchain.blockchainId),
                        request.sender,
                        request.recipient,
                        request.token,
                        request.amount,
                        request.serviceNode,
                        request.fee,
                        request.nonce,
                        request.validUntil,
                        PANTOS_HUB_ADDRESS,
                        address(pantosForwarder),
                        PANTOS_TOKEN_ADDRESS
                    )
                )
            );
    }

    function getDigest(
        PantosTypes.TransferFromRequest memory request
    ) public view returns (bytes32) {
        return
            MessageHashUtils.toEthSignedMessageHash(
                keccak256(
                    abi.encodePacked(
                        uint256(thisBlockchain.blockchainId),
                        request.destinationBlockchainId,
                        request.sender,
                        request.recipient,
                        request.sourceToken,
                        request.destinationToken,
                        request.amount,
                        request.serviceNode,
                        request.fee,
                        request.nonce,
                        // Required because of solc stack depth limit
                        abi.encodePacked(
                            request.validUntil,
                            PANTOS_HUB_ADDRESS,
                            address(pantosForwarder),
                            PANTOS_TOKEN_ADDRESS
                        )
                    )
                )
            );
    }

    function getDigest(
        PantosTypes.TransferToRequest memory request
    ) public view returns (bytes32) {
        return
            MessageHashUtils.toEthSignedMessageHash(
                keccak256(
                    abi.encodePacked(
                        request.sourceBlockchainId,
                        uint256(thisBlockchain.blockchainId),
                        request.sourceTransactionId,
                        request.sourceTransferId,
                        request.sender,
                        request.recipient,
                        request.sourceToken,
                        request.destinationToken,
                        request.amount,
                        request.nonce,
                        // Required because of solc stack depth limit
                        abi.encodePacked(
                            PANTOS_HUB_ADDRESS,
                            address(pantosForwarder),
                            PANTOS_TOKEN_ADDRESS
                        )
                    )
                )
            );
    }
}
