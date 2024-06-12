// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;
pragma abicoder v2;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {PantosTypes} from "../src/interfaces/PantosTypes.sol";
import {IPantosForwarder} from "./interfaces/IPantosForwarder.sol";
import {IPantosHub} from "./interfaces/IPantosHub.sol";
import {IPantosToken} from "./interfaces/IPantosToken.sol";

uint256 constant DEFAULT_MINIMUM_VALIDATOR_NODE_SIGNATURES = 3;
uint constant INVALID_VALIDATOR_NODE_INDEX = type(uint).max;

/**
 * @title Pantos Forwarder
 *
 * @notice See {IPantosForwarder}.
 *
 * @dev See {IPantosForwarder}.
 */
contract PantosForwarder is IPantosForwarder, Ownable, Pausable {
    address private _pantosHub;

    address private _pantosToken;

    uint256 private _minimumValidatorNodeSignatures =
        DEFAULT_MINIMUM_VALIDATOR_NODE_SIGNATURES;

    // Validator node addresses ordered from lowest to highest
    address[] private _validatorNodeAddresses;

    // Used validator node nonces (to prevent replay attacks)
    mapping(uint256 => bool) private _usedValidatorNodeNonces;

    // Used nonces of senders (to prevent replay attacks)
    mapping(address => mapping(uint256 => bool)) private _usedSenderNonces;

    constructor() Ownable(msg.sender) {
        // Contract is paused until it is fully initialized
        _pause();
    }

    /**
     * @notice Modifier making sure that the function can only be called by the
     * Pantos Hub.
     */
    modifier onlyPantosHub() {
        require(
            msg.sender == _pantosHub,
            "PantosForwarder: caller is not the PantosHub"
        );
        _;
    }

    /**
     * @dev See {Pausable-_pause}.
     */
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    /**
     * @dev See {Pausable-_unpause}.
     */
    function unpause() external whenPaused onlyOwner {
        require(
            _pantosHub != address(0),
            "PantosForwarder: PantosHub has not been set"
        );
        require(
            _pantosToken != address(0),
            "PantosForwarder: PantosToken has not been set"
        );
        require(
            _validatorNodeAddresses.length >= _minimumValidatorNodeSignatures,
            "PantosForwarder: not enough validator nodes added"
        );
        _unpause();
    }

    /**
     * @notice Used by the owner of the Pantos Forwarder to set a new Pantos
     * Hub address
     *
     * @param pantosHub The new Pantos Hub address
     *
     * @dev The function is only callable by the owner of the Pantos Forwarder
     * contract and can only be called when the contract is paused.
     */
    function setPantosHub(address pantosHub) external whenPaused onlyOwner {
        require(
            pantosHub != address(0),
            "PantosForwarder: PantosHub must not be the zero account"
        );
        _pantosHub = pantosHub;
        emit PantosHubSet(pantosHub);
    }

    /**
     * @notice Used by the owner of the Pantos Forwarder to set a new Pantos
     * Token address
     *
     * @param pantosToken The new Pantos Token address
     *
     * @dev The function is only callable by the owner of the Pantos Forwarder
     * contract and can only be called when the contract is paused.
     */
    function setPantosToken(
        address pantosToken
    ) external whenPaused onlyOwner {
        require(
            pantosToken != address(0),
            "PantosForwarder: PantosToken must not be the zero account"
        );
        _pantosToken = pantosToken;
        emit PantosTokenSet(pantosToken);
    }

    /**
     * @notice Update the minimum number of validator node signatures
     * for validating a cross-chain transfer.
     *
     * @param minimumValidatorNodeSignatures The minimum number of
     * signatures.
     *
     * @dev The function can only be called by the owner of the contract
     * and only if the contract is paused.
     */
    function setMinimumValidatorNodeSignatures(
        uint256 minimumValidatorNodeSignatures
    ) external whenPaused onlyOwner {
        require(
            minimumValidatorNodeSignatures > 0,
            "PantosForwarder: at least one signature required"
        );
        _minimumValidatorNodeSignatures = minimumValidatorNodeSignatures;
        emit MinimumValidatorNodeSignaturesUpdated(
            minimumValidatorNodeSignatures
        );
    }

    /**
     * @notice Add a new node to the validator network.
     *
     * @param validatorNodeAddress The address of the validator node.
     *
     * @dev The function can only be called by the owner of the contract
     * and only if the contract is paused.
     */
    function addValidatorNode(
        address validatorNodeAddress
    ) external whenPaused onlyOwner {
        require(
            validatorNodeAddress != address(0),
            "PantosForwarder: validator node address must not be zero"
        );
        _validatorNodeAddresses.push(validatorNodeAddress);
        uint newNumberValidatorNodes = _validatorNodeAddresses.length;
        // Keep the ordering from the lowest to the highest address
        if (newNumberValidatorNodes > 1) {
            address otherValidatorNodeAddress;
            for (uint i = newNumberValidatorNodes - 1; i > 0; i--) {
                otherValidatorNodeAddress = _validatorNodeAddresses[i - 1];
                require(
                    otherValidatorNodeAddress != validatorNodeAddress,
                    "PantosForwarder: validator node already added"
                );
                if (otherValidatorNodeAddress < validatorNodeAddress) {
                    break;
                }
                _validatorNodeAddresses[i] = otherValidatorNodeAddress;
                _validatorNodeAddresses[i - 1] = validatorNodeAddress;
            }
        }
        emit ValidatorNodeAdded(validatorNodeAddress);
    }

    /**
     * @notice Remove a node from the validator network.
     *
     * @param validatorNodeAddress The address of the validator node.
     *
     * @dev The function can only be called by the owner of the contract
     * and only if the contract is paused.
     */
    function removeValidatorNode(
        address validatorNodeAddress
    ) external whenPaused onlyOwner {
        require(
            validatorNodeAddress != address(0),
            "PantosForwarder: validator node address must not be zero"
        );
        uint validatorNodeIndex = _getValidatorNodeIndex(validatorNodeAddress);
        require(
            validatorNodeIndex != INVALID_VALIDATOR_NODE_INDEX,
            "PantosForwarder: validator node not added"
        );
        uint newNumberValidatorNodes = _validatorNodeAddresses.length - 1;
        // Keep the ordering from the lowest to the highest address
        for (uint i = validatorNodeIndex; i < newNumberValidatorNodes; i++) {
            _validatorNodeAddresses[i] = _validatorNodeAddresses[i + 1];
        }
        _validatorNodeAddresses.pop();
        emit ValidatorNodeRemoved(validatorNodeAddress);
    }

    /**
     * @dev See {IPantosForwarder-verifyAndForwardTransfer}.
     */
    function verifyAndForwardTransfer(
        PantosTypes.TransferRequest calldata request,
        bytes memory signature
    ) external override whenNotPaused onlyPantosHub {
        // Verify the nonce and signature
        verifyTransfer(request, signature);
        // Mark the nonce as used
        _usedSenderNonces[request.sender][request.nonce] = true;
        // Transfer the tokens from the sender to the recipient
        IPantosToken(request.token).pantosTransfer(
            request.sender,
            request.recipient,
            request.amount
        );
        // Transfer the fee to the service node
        IPantosToken(_pantosToken).pantosTransfer(
            request.sender,
            request.serviceNode,
            request.fee
        );
    }

    /**
     * @dev See {IPantosForwarder-verifyAndForwardTransferFrom}.
     */
    function verifyAndForwardTransferFrom(
        uint256 sourceBlockchainFactor,
        uint256 destinationBlockchainFactor,
        PantosTypes.TransferFromRequest calldata request,
        bytes memory signature
    ) external override whenNotPaused onlyPantosHub {
        // Verify the nonce and signature
        verifyTransferFrom(request, signature);
        // Mark the nonce as used
        _usedSenderNonces[request.sender][request.nonce] = true;
        // Transfer the tokens from the sender
        IPantosToken(request.sourceToken).pantosTransferFrom(
            request.sender,
            request.amount
        );
        // Transfer the fee to the service and validator nodes
        _transferFee(
            request.sender,
            request.serviceNode,
            request.fee,
            sourceBlockchainFactor,
            destinationBlockchainFactor
        );
    }

    /**
     * @dev See {IPantosForwarder-verifyAndForwardTransferTo}.
     */
    function verifyAndForwardTransferTo(
        PantosTypes.TransferToRequest memory request,
        address[] memory signerAddresses,
        bytes[] memory signatures
    ) external override whenNotPaused onlyPantosHub {
        // Verify the nonce and signatures
        verifyTransferTo(request, signerAddresses, signatures);
        // Mark the nonce as used
        _usedValidatorNodeNonces[request.nonce] = true;
        // Transfer the tokens to the recipient
        IPantosToken(request.destinationToken).pantosTransferTo(
            request.recipient,
            request.amount
        );
    }

    /**
     * @dev See {IPantosForwarder-getPantosHub}.
     */
    function getPantosHub() public view override returns (address) {
        return _pantosHub;
    }

    /**
     * @dev See {IPantosForwarder-getPantosToken}.
     */
    function getPantosToken() public view override returns (address) {
        return _pantosToken;
    }

    /**
     * @dev See {IPantosForwarder-getMinimumValidatorNodeSignatures}.
     */
    function getMinimumValidatorNodeSignatures()
        external
        view
        override
        returns (uint256)
    {
        return _minimumValidatorNodeSignatures;
    }

    /**
     * @dev See {IPantosForwarder-getValidatorNodes}.
     */
    function getValidatorNodes()
        external
        view
        override
        returns (address[] memory)
    {
        return _validatorNodeAddresses;
    }

    /**
     * @dev See {IPantosForwarder-isValidValidatorNodeNonce}.
     */
    function isValidValidatorNodeNonce(
        uint256 nonce
    ) external view override onlyPantosHub returns (bool) {
        return !_usedValidatorNodeNonces[nonce];
    }

    /**
     * @dev See {IPantosForwarder-isValidSenderNonce}.
     */
    function isValidSenderNonce(
        address sender,
        uint256 nonce
    ) public view override onlyPantosHub returns (bool) {
        return !_usedSenderNonces[sender][nonce];
    }

    /**
     * @dev See {IPantosForwarder-verifyTransfer}.
     */
    function verifyTransfer(
        PantosTypes.TransferRequest calldata request,
        bytes memory signature
    ) public view override onlyPantosHub {
        // Token and service node are verified by the PantosHub
        // In a token transfer within a single blockchain, the sender and
        // recipient addresses must not be identical
        require(
            request.sender != request.recipient,
            "PantosForwarder: sender and recipient must not be identical"
        );
        // Verify the amount, sender nonce, validity period, and signature
        _verifyAmount(request.amount);
        _verifySenderNonce(request.sender, request.nonce);
        _verifyValidUntil(request.validUntil);
        _verifyTransferSignature(request, signature);
    }

    /**
     * @dev See {IPantosForwarder-verifyTransferFrom}.
     */
    function verifyTransferFrom(
        PantosTypes.TransferFromRequest calldata request,
        bytes memory signature
    ) public view override onlyPantosHub {
        // Destination blockchain, token, and service node are verified by the
        // PantosHub
        // Verify the amount, sender nonce, validity period, and signature
        _verifyAmount(request.amount);
        _verifySenderNonce(request.sender, request.nonce);
        _verifyValidUntil(request.validUntil);
        _verifyTransferFromSignature(request, signature);
    }

    /**
     * @dev See {IPantosForwarder-verifyTransferTo}.
     */
    function verifyTransferTo(
        PantosTypes.TransferToRequest memory request,
        address[] memory signerAddresses,
        bytes[] memory signatures
    ) public view override onlyPantosHub {
        // Source blockchain and token are verified by the PantosHub
        // Verify the amount, validator nonce, and signatures
        _verifyAmount(request.amount);
        _verifyValidatorNodeNonce(request.nonce);
        _verifyTransferToSignatures(request, signerAddresses, signatures);
    }

    function _getValidatorNodeIndex(
        address validatorNodeAddress
    ) private view returns (uint) {
        return _getValidatorNodeIndex(validatorNodeAddress, 0);
    }

    function _getValidatorNodeIndex(
        address validatorNodeAddress,
        uint startIndex
    ) private view returns (uint) {
        uint numberValidatorNodes = _validatorNodeAddresses.length;
        for (uint i = startIndex; i < numberValidatorNodes; i++) {
            if (_validatorNodeAddresses[i] == validatorNodeAddress) {
                return i;
            }
        }
        return INVALID_VALIDATOR_NODE_INDEX;
    }

    function _verifyAmount(uint256 amount) private pure {
        require(amount > 0, "PantosForwarder: amount must be greater than 0");
    }

    function _verifyValidatorNodeNonce(uint256 nonce) private view {
        require(
            !_usedValidatorNodeNonces[nonce],
            "PantosForwarder: validator node nonce invalid"
        );
    }

    function _verifySenderNonce(address sender, uint256 nonce) private view {
        require(
            !_usedSenderNonces[sender][nonce],
            "PantosForwarder: sender nonce invalid"
        );
    }

    function _verifyValidUntil(uint256 validUntil) private view {
        // slither-disable-next-line timestamp
        require(
            block.timestamp <= validUntil,
            "PantosForwarder: validity period has expired"
        );
    }

    function _verifyTransferSignature(
        PantosTypes.TransferRequest calldata request,
        bytes memory signature
    ) private view {
        // Recreate the base message that was signed
        bytes32 baseMessage = keccak256(_encodeTransferMessage(request));
        // Verify that the sender signed the message
        _verifySignature(baseMessage, request.sender, signature);
    }

    function _verifyTransferFromSignature(
        PantosTypes.TransferFromRequest calldata request,
        bytes memory signature
    ) private view {
        // Recreate the base message that was signed
        bytes32 baseMessage = keccak256(_encodeTransferFromMessage(request));
        // Verify that the sender signed the message
        _verifySignature(baseMessage, request.sender, signature);
    }

    function _verifyTransferToSignatures(
        PantosTypes.TransferToRequest memory request,
        address[] memory signerAddresses,
        bytes[] memory signatures
    ) private view {
        // Recreate the base message that was signed
        bytes32 baseMessage = keccak256(_encodeTransferToMessage(request));
        // Verify that enough validator nodes signed the message
        uint numberSigners = signerAddresses.length;
        require(
            numberSigners == signatures.length,
            "PantosForwarder: numbers of signers and signatures must match"
        );
        require(
            numberSigners >= _minimumValidatorNodeSignatures,
            "PantosForwarder: insufficient number of signatures"
        );
        address previousSignerAddress = address(0);
        address currentSignerAddress;
        uint validatorNodeIndex = 0;
        for (uint i = 0; i < numberSigners; i++) {
            currentSignerAddress = signerAddresses[i];
            // Ensure that the signer address is unique and non-zero
            require(
                currentSignerAddress > previousSignerAddress,
                string.concat(
                    "PantosForwarder: invalid signer ",
                    Strings.toHexString(currentSignerAddress)
                )
            );
            // Search only from the given start index to improve the gas
            // efficiency (which is possible due to the ordering of the
            // validator node addresses)
            validatorNodeIndex = _getValidatorNodeIndex(
                currentSignerAddress,
                validatorNodeIndex
            );
            require(
                validatorNodeIndex != INVALID_VALIDATOR_NODE_INDEX,
                string.concat(
                    "PantosForwarder: non-validator signer ",
                    Strings.toHexString(currentSignerAddress)
                )
            );
            _verifySignature(baseMessage, currentSignerAddress, signatures[i]);
            previousSignerAddress = currentSignerAddress;
            validatorNodeIndex++;
        }
    }

    function _verifySignature(
        bytes32 baseMessage,
        address signerAddress,
        bytes memory signature
    ) private pure {
        // Recreate the message that was signed
        bytes32 message = MessageHashUtils.toEthSignedMessageHash(baseMessage);
        // Recover the signer's address from the signature
        address recoveredSignerAddress = ECDSA.recover(message, signature);
        require(
            recoveredSignerAddress == signerAddress,
            string.concat(
                "PantosForwarder: invalid signature by ",
                Strings.toHexString(signerAddress)
            )
        );
    }

    function _transferFee(
        address sender,
        address serviceNode,
        uint256 fee,
        uint256 sourceBlockchainFactor,
        uint256 destinationBlockchainFactor
    ) private {
        uint256 totalFactor = sourceBlockchainFactor +
            destinationBlockchainFactor;
        uint256 serviceNodeFee = (sourceBlockchainFactor * fee) / totalFactor;
        uint256 validatorFee = fee - serviceNodeFee;
        IPantosToken pantosToken = IPantosToken(_pantosToken);
        pantosToken.pantosTransfer(sender, serviceNode, serviceNodeFee);
        pantosToken.pantosTransfer(
            sender,
            IPantosHub(_pantosHub).getPrimaryValidatorNode(),
            validatorFee
        );
    }

    function _encodeTransferMessage(
        PantosTypes.TransferRequest calldata request
    ) private view returns (bytes memory) {
        return
            abi.encodePacked(
                IPantosHub(_pantosHub).getCurrentBlockchainId(),
                request.sender,
                request.recipient,
                request.token,
                request.amount,
                request.serviceNode,
                request.fee,
                request.nonce,
                request.validUntil,
                _pantosHub,
                address(this),
                _pantosToken
            );
    }

    function _encodeTransferFromMessage(
        PantosTypes.TransferFromRequest calldata request
    ) private view returns (bytes memory) {
        return
            abi.encodePacked(
                IPantosHub(_pantosHub).getCurrentBlockchainId(),
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
                    _pantosHub,
                    address(this),
                    _pantosToken
                )
            );
    }

    function _encodeTransferToMessage(
        PantosTypes.TransferToRequest memory request
    ) private view returns (bytes memory) {
        uint256 destinationBlockchainId = IPantosHub(_pantosHub)
            .getCurrentBlockchainId();
        return
            abi.encodePacked(
                request.sourceBlockchainId,
                destinationBlockchainId,
                request.sourceTransactionId,
                request.sourceTransferId,
                request.sender,
                request.recipient,
                request.sourceToken,
                request.destinationToken,
                request.amount,
                request.nonce,
                // Required because of solc stack depth limit
                abi.encodePacked(_pantosHub, address(this), _pantosToken)
            );
    }
}
