// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

/* solhint-disable no-console*/

import "forge-std/console2.sol";

import "../src/contracts/PantosForwarder.sol";
import "../src/interfaces/PantosTypes.sol";

import "./PantosBaseTest.t.sol";

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
        for (uint256 i = 0; i < length; i++) {
            validatorCount = testSets[i];
            setUp();
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
        vm.expectRevert(
            abi.encodePacked("PantosForwarder: PantosHub has not been set")
        );

        pantosForwarder.unpause();
    }

    function test_unpause_WithNoPantosTokenSet() external {
        pantosForwarder.setPantosHub(PANTOS_HUB_ADDRESS);
        vm.expectRevert(
            abi.encodePacked("PantosForwarder: PantosToken has not been set")
        );

        pantosForwarder.unpause();
    }

    function test_unpause_WithNoValidatorSet() external {
        pantosForwarder.setPantosHub(PANTOS_HUB_ADDRESS);
        pantosForwarder.setPantosToken(PANTOS_TOKEN_ADDRESS);
        vm.expectRevert(
            abi.encodePacked(
                "PantosForwarder: not enough validator nodes added"
            )
        );

        pantosForwarder.unpause();
    }

    function test_unpause_WithLessThanMinValidatorSet() external {
        pantosForwarder.setPantosHub(PANTOS_HUB_ADDRESS);
        pantosForwarder.setPantosToken(PANTOS_TOKEN_ADDRESS);
        pantosForwarder.setMinimumValidatorNodeSignatures(3);
        pantosForwarder.addValidatorNode(validatorAddress);
        pantosForwarder.addValidatorNode(validatorAddress2);
        vm.expectRevert(
            abi.encodePacked(
                "PantosForwarder: not enough validator nodes added"
            )
        );

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
            abi.encodePacked(
                "PantosForwarder: PantosHub must not be the zero account"
            )
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
            abi.encodePacked(
                "PantosForwarder: PantosToken must not be the zero account"
            )
        );

        pantosForwarder.setPantosToken(ADDRESS_ZERO);
    }

    function test_setMinimumValidatorNodeSignatures() external {
        vm.expectEmit(address(pantosForwarder));
        emit IPantosForwarder.MinimumValidatorNodeSignaturesUpdated(1);

        pantosForwarder.setMinimumValidatorNodeSignatures(1);

        assertEq(pantosForwarder.getMinimumValidatorNodeSignatures(), 1);
    }

    function test_setMinimumValidatorNodeSignaturesWith0() external {
        vm.expectRevert(
            abi.encodePacked(
                "PantosForwarder: at least one signature required"
            )
        );

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

    function test_verifyAndForwardTransfer()
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
        vm.prank(PANTOS_HUB_ADDRESS);

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
        mockAndExpectPantosHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        mockAndExpectPantosBaseToken_pantosTransferFrom(request);
        uint256 sourceBlockchainFactor = 2;
        uint256 destinationBlockchainFactor = 2;
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
        vm.prank(PANTOS_HUB_ADDRESS);

        pantosForwarder.verifyAndForwardTransferFrom(1, 1, request, signature);
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
        mockAndExpectPantosHub_getCurrentBlockchainId(
            thisBlockchain.blockchainId
        );
        mockAndExpectPantosBaseToken_pantosTransferTo(
            request.destinationToken,
            request.recipient,
            request.amount
        );
        vm.prank(PANTOS_HUB_ADDRESS);

        pantosForwarder.verifyAndForwardTransferTo(
            request,
            signerAddresses,
            signatures
        );
    }

    //  All the mock utils here
    function mockAndExpectPantosHub_getPrimaryValidatorNode() public {
        vm.mockCall(
            PANTOS_HUB_ADDRESS,
            abi.encodeWithSelector(PantosHub.getPrimaryValidatorNode.selector),
            abi.encode(validatorAddress)
        );

        vm.expectCall(
            PANTOS_HUB_ADDRESS,
            abi.encodeWithSelector(PantosHub.getPrimaryValidatorNode.selector)
        );
    }

    function mockAndExpectPantosHub_getCurrentBlockchainId(
        BlockchainId blockchainId
    ) public {
        vm.mockCall(
            PANTOS_HUB_ADDRESS,
            abi.encodeWithSelector(PantosHub.getCurrentBlockchainId.selector),
            abi.encode(uint256(blockchainId))
        );

        vm.expectCall(
            PANTOS_HUB_ADDRESS,
            abi.encodeWithSelector(PantosHub.getCurrentBlockchainId.selector)
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
        // Set the hub, PAN token, and trusted validator addresses
        pantosForwarder.setPantosHub(PANTOS_HUB_ADDRESS);
        pantosForwarder.setPantosToken(PANTOS_TOKEN_ADDRESS);
        pantosForwarder.setMinimumValidatorNodeSignatures(
            validatorNodeAddresses.length
        );
        for (uint i = 0; i < validatorNodeAddresses.length; i++) {
            pantosForwarder.addValidatorNode(validatorNodeAddresses[i]);
            console2.log(
                "PantosForwarder.addValidatorNode(%s)",
                validatorNodeAddresses[i]
            );
        }

        // Unpause the forwarder contract after initialization
        pantosForwarder.unpause();
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
            emit log_address(signerAddresses[i]);
            emit log_address(_validatorWallets[signerAddresses[i]].addr);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                _validatorWallets[signerAddresses[i]],
                digest
            );
            signatures[i] = abi.encodePacked(r, s, v);
        }
        return signatures;
    }

    function getDigest(
        PantosTypes.TransferRequest memory request
    ) public view returns (bytes32) {
        return
            ECDSA.toEthSignedMessageHash(
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
            ECDSA.toEthSignedMessageHash(
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
            ECDSA.toEthSignedMessageHash(
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
