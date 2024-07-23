// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PantosTypes} from "../interfaces/PantosTypes.sol";
import {IPantosForwarder} from "../interfaces/IPantosForwarder.sol";
import {IPantosToken} from "../interfaces/IPantosToken.sol";
import {IPantosTransfer} from "../interfaces/IPantosTransfer.sol";

import {PantosBaseFacet} from "./PantosBaseFacet.sol";

/**
 * @title Pantos Transfer facet
 *
 * @notice See {IPantosTransfer}.
 */
contract PantosTransferFacet is IPantosTransfer, PantosBaseFacet {
    /**
     * @dev See {IPantosTransfer-transfer}.
     */
    function transfer(
        PantosTypes.TransferRequest calldata request,
        bytes memory signature
    ) external override whenNotPaused returns (uint256) {
        // Caller must be the service node in the transfer request
        require(
            msg.sender == request.serviceNode,
            "PantosHub: caller must be the service node"
        );
        // Verify the token and service node
        _verifyTransfer(request);
        // Assign a new transfer ID
        uint256 transferId = s.nextTransferId++;
        emit Transfer(
            transferId,
            request.sender,
            request.recipient,
            request.token,
            request.amount,
            request.fee,
            request.serviceNode
        );
        // Forward the transfer request
        IPantosForwarder(s.pantosForwarder).verifyAndForwardTransfer(
            request,
            signature
        );
        return transferId;
    }

    /**
     * @dev See {IPantosTransfer-transferFrom}.
     */
    function transferFrom(
        PantosTypes.TransferFromRequest calldata request,
        bytes memory signature
    ) external override whenNotPaused returns (uint256) {
        // Caller must be the service node in the transfer request
        require(
            msg.sender == request.serviceNode,
            "PantosHub: caller must be the service node"
        );
        // Verify the destination blockchain, token, and service node
        _verifyTransferFrom(request);
        // Assign a new transfer ID
        uint256 sourceTransferId = s.nextTransferId++;
        emit TransferFrom(
            sourceTransferId,
            request.destinationBlockchainId,
            request.sender,
            request.recipient,
            request.sourceToken,
            request.destinationToken,
            request.amount,
            request.fee,
            request.serviceNode
        );
        // Forward the transfer request
        {
            // Scope for verifying and forwarding the TransferFromRequest,
            // avoids stack too deep exception
            uint256 sourceBlockchainFactor;
            uint256 destinationBlockchainFactor;
            PantosTypes.ValidatorFeeRecord memory sourceFeeRecord = s
                .validatorFeeRecords[s.currentBlockchainId];
            PantosTypes.ValidatorFeeRecord memory destinationFeeRecord = s
                .validatorFeeRecords[request.destinationBlockchainId];
            // slither-disable-next-line timestamp
            if (block.timestamp >= sourceFeeRecord.validFrom) {
                sourceBlockchainFactor = sourceFeeRecord.newFactor;
            } else {
                sourceBlockchainFactor = sourceFeeRecord.oldFactor;
            }
            // slither-disable-next-line timestamp
            if (block.timestamp >= destinationFeeRecord.validFrom) {
                destinationBlockchainFactor = destinationFeeRecord.newFactor;
            } else {
                destinationBlockchainFactor = destinationFeeRecord.oldFactor;
            }
            IPantosForwarder(s.pantosForwarder).verifyAndForwardTransferFrom(
                sourceBlockchainFactor,
                destinationBlockchainFactor,
                request,
                signature
            );
        }
        return sourceTransferId;
    }

    /**
     * @dev See {IPantosTransfer-transferTo}.
     */
    function transferTo(
        PantosTypes.TransferToRequest memory request,
        address[] memory signerAddresses,
        bytes[] memory signatures
    )
        external
        override
        whenNotPaused
        onlyPrimaryValidatorNode
        returns (uint256)
    {
        // Verify the source blockchain and token
        _verifyTransferTo(request);
        // Mark the source transfer ID as used
        s.usedSourceTransferIds[request.sourceBlockchainId][
            request.sourceTransferId
        ] = true;
        // Assign a new transfer ID
        uint256 destinationTransferId = s.nextTransferId++;
        emit TransferTo(
            request.sourceBlockchainId,
            request.sourceTransferId,
            request.sourceTransactionId,
            destinationTransferId,
            request.sender,
            request.recipient,
            request.sourceToken,
            request.destinationToken,
            request.amount,
            request.nonce,
            signerAddresses,
            signatures
        );
        // Forward the transfer request
        IPantosForwarder(s.pantosForwarder).verifyAndForwardTransferTo(
            request,
            signerAddresses,
            signatures
        );
        return destinationTransferId;
    }

    /**
     * @dev See {IPantosTransfer-isValidSenderNonce}.
     */
    function isValidSenderNonce(
        address sender,
        uint256 nonce
    ) external view override returns (bool) {
        return
            IPantosForwarder(s.pantosForwarder).isValidSenderNonce(
                sender,
                nonce
            );
    }

    /**
     * @dev See {IPantosTransfer-verifyTransfer}.
     */
    function verifyTransfer(
        PantosTypes.TransferRequest calldata request,
        bytes memory signature
    ) external view override {
        // Verify the token and service node
        _verifyTransfer(request);
        // Verify the remaining transfer request (including the signature)
        IPantosForwarder(s.pantosForwarder).verifyTransfer(request, signature);
        // Verify the sender's balance
        _verifyTransferBalance(
            request.sender,
            request.token,
            request.amount,
            request.fee
        );
    }

    /**
     * @dev See {IPantosTransfer-verifyTransferFrom}.
     */
    function verifyTransferFrom(
        PantosTypes.TransferFromRequest calldata request,
        bytes memory signature
    ) external view override {
        // Verify the destination blockchain, token, and service node
        _verifyTransferFrom(request);
        // Verify the remaining transfer request (including the signature)
        IPantosForwarder(s.pantosForwarder).verifyTransferFrom(
            request,
            signature
        );
        // Verify the sender's balance
        _verifyTransferBalance(
            request.sender,
            request.sourceToken,
            request.amount,
            request.fee
        );
    }

    /**
     * @dev See {IPantosTransfer-verifyTransferTo}.
     */
    function verifyTransferTo(
        PantosTypes.TransferToRequest memory request,
        address[] memory signerAddresses,
        bytes[] memory signatures
    ) external view override {
        // Verify the source blockchain and token
        _verifyTransferTo(request);
        // Verify the remaining transfer request (including the signatures)
        IPantosForwarder(s.pantosForwarder).verifyTransferTo(
            request,
            signerAddresses,
            signatures
        );
    }

    function getNextTransferId() public view returns (uint256) {
        return s.nextTransferId;
    }

    function _verifyTransfer(
        PantosTypes.TransferRequest calldata request
    ) private view {
        // Verify the token
        _verifyTransferToken(request.token);
        // Verify if the service node is active
        _verifyTransferServiceNode(request.serviceNode);
    }

    function _verifyTransferFrom(
        PantosTypes.TransferFromRequest calldata request
    ) private view {
        // Verify the destination blockchain
        require(
            request.destinationBlockchainId != s.currentBlockchainId,
            "PantosHub: source and destination blockchains must not be equal"
        );
        _verifyTransferBlockchain(request.destinationBlockchainId);
        // Verify the source and destination token
        _verifyTransferToken(request.sourceToken);
        _verifyTransferExternalToken(
            request.sourceToken,
            request.destinationBlockchainId,
            request.destinationToken
        );
        // Verify if the service node is active
        _verifyTransferServiceNode(request.serviceNode);
    }

    function _verifyTransferTo(
        PantosTypes.TransferToRequest memory request
    ) private view {
        if (request.sourceBlockchainId != s.currentBlockchainId) {
            _verifyTransferBlockchain(request.sourceBlockchainId);
            _verifyTransferExternalToken(
                request.destinationToken,
                request.sourceBlockchainId,
                request.sourceToken
            );
        }
        _verifyTransferToken(request.destinationToken);
        _verifySourceTransferId(
            request.sourceBlockchainId,
            request.sourceTransferId
        );
    }

    function _verifyTransferBlockchain(uint256 blockchainId) private view {
        // Blockchain must be active
        PantosTypes.BlockchainRecord storage blockchainRecord = s
            .blockchainRecords[blockchainId];
        require(
            blockchainRecord.active,
            "PantosHub: blockchain must be active"
        );
    }

    function _verifyTransferToken(address token) private view {
        PantosTypes.TokenRecord storage tokenRecord = s.tokenRecords[token];
        require(tokenRecord.active, "PantosHub: token must be registered");
        require(
            IPantosToken(token).getPantosForwarder() == s.pantosForwarder,
            "PantosHub: Forwarder of Hub and transferred token must match"
        );
    }

    function _verifyTransferExternalToken(
        address token,
        uint256 blockchainId,
        string memory externalToken
    ) private view {
        // External token must be active
        PantosTypes.ExternalTokenRecord storage externalTokenRecord = s
            .externalTokenRecords[token][blockchainId];
        require(
            externalTokenRecord.active,
            "PantosHub: external token must be registered"
        );
        // Registered external token must match the external token of the
        // transfer
        require(
            keccak256(bytes(externalTokenRecord.externalToken)) ==
                keccak256(bytes(externalToken)),
            "PantosHub: incorrect external token"
        );
    }

    function _verifyTransferServiceNode(address serviceNode) private view {
        // Service node must be active
        PantosTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[serviceNode];
        require(
            serviceNodeRecord.active,
            "PantosHub: service node must be registered"
        );
        // Service node must have enough deposit
        require(
            serviceNodeRecord.deposit >= s.minimumServiceNodeDeposit,
            "PantosHub: service node must have enough deposit"
        );
    }

    function _verifyTransferBalance(
        address sender,
        address token,
        uint256 amount,
        uint256 fee
    ) private view {
        if (token == s.pantosToken) {
            require(
                (amount + fee) <= IERC20(s.pantosToken).balanceOf(sender),
                "PantosHub: insufficient balance of sender"
            );
        } else {
            require(
                amount <= IERC20(token).balanceOf(sender),
                "PantosHub: insufficient balance of sender"
            );
            require(
                fee <= IERC20(s.pantosToken).balanceOf(sender),
                "PantosHub: insufficient balance of sender for fee payment"
            );
        }
    }

    function _verifySourceTransferId(
        uint256 sourceBlockchainId,
        uint256 sourceTransferId
    ) private view {
        // Source transfer ID must not have been used before
        require(
            !s.usedSourceTransferIds[sourceBlockchainId][sourceTransferId],
            "PantosHub: source transfer ID already used"
        );
    }
}
