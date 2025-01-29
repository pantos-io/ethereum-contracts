// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

/**
 * @title Common Pantos types
 */
library PantosTypes {
    struct BlockchainRecord {
        bool active;
        string name;
    }

    struct TokenRecord {
        bool active;
    }

    struct ExternalTokenRecord {
        bool active;
        string externalToken; // External token address
    }

    struct ServiceNodeRecord {
        bool active;
        string url;
        uint256 deposit;
        address withdrawalAddress;
        uint256 withdrawalTime;
    }

    struct TransferRequest {
        address sender;
        address recipient;
        address token;
        uint256 amount;
        address serviceNode;
        uint256 fee;
        uint256 nonce;
        uint256 validUntil;
    }

    string constant TRANSFER_REQUEST_TYPE =
        "TransferRequest("
        "address sender,"
        "address recipient,"
        "address token,"
        "uint256 amount,"
        "address serviceNode,"
        "uint256 fee,"
        "uint256 nonce,"
        "uint256 validUntil)";

    /**
     * @notice The typed structured data to be signed by a Pantos client
     * for a single-chain transfer.
     */
    struct Transfer {
        TransferRequest request;
        uint256 blockchainId;
        address pantosHub;
        address pantosForwarder;
        address pantosToken;
    }

    string constant TRANSFER_TYPE =
        "Transfer("
        "TransferRequest request,"
        "uint256 blockchainId,"
        "address pantosHub,"
        "address pantosForwarder,"
        "address pantosToken)";

    struct TransferFromRequest {
        uint256 destinationBlockchainId;
        address sender;
        string recipient; // Recipient address on destination blockchain
        address sourceToken;
        string destinationToken; // Token address on destination blockchain
        uint256 amount;
        address serviceNode;
        uint256 fee;
        uint256 nonce;
        uint256 validUntil;
    }

    string constant TRANSFER_FROM_REQUEST_TYPE =
        "TransferFromRequest("
        "uint256 destinationBlockchainId,"
        "address sender,"
        "string recipient,"
        "address sourceToken,"
        "string destinationToken,"
        "uint256 amount,"
        "address serviceNode,"
        "uint256 fee,"
        "uint256 nonce,"
        "uint256 validUntil)";

    /**
     * @notice The typed structured data to be signed by a Pantos client
     * for a cross-chain transfer.
     */
    struct TransferFrom {
        TransferFromRequest request;
        uint256 sourceBlockchainId;
        address pantosHub;
        address pantosForwarder;
        address pantosToken;
    }

    string constant TRANSFER_FROM_TYPE =
        "TransferFrom("
        "TransferFromRequest request,"
        "uint256 sourceBlockchainId,"
        "address pantosHub,"
        "address pantosForwarder,"
        "address pantosToken)";

    struct TransferToRequest {
        uint256 sourceBlockchainId;
        uint256 sourceTransferId; // Pantos transfer ID
        string sourceTransactionId; // Blockchain transaction ID/hash
        string sender; // Sender address on source blockchain
        address recipient;
        string sourceToken; // Token address on source blockchain
        address destinationToken;
        uint256 amount;
        uint256 nonce;
    }

    string constant TRANSFER_TO_REQUEST_TYPE =
        "TransferToRequest("
        "uint256 sourceBlockchainId,"
        "uint256 sourceTransferId,"
        "string sourceTransactionId,"
        "string sender,"
        "address recipient,"
        "string sourceToken,"
        "address destinationToken,"
        "uint256 amount,"
        "uint256 nonce)";

    /**
     * @notice The typed structured data to be signed by a Pantos
     * validator node for a cross-chain transfer.
     */
    struct TransferTo {
        TransferToRequest request;
        uint256 destinationBlockchainId;
        address pantosHub;
        address pantosForwarder;
        address pantosToken;
    }

    string constant TRANSFER_TO_TYPE =
        "TransferTo("
        "TransferToRequest request,"
        "uint256 destinationBlockchainId,"
        "address pantosHub,"
        "address pantosForwarder,"
        "address pantosToken)";

    struct UpdatableUint256 {
        uint256 currentValue;
        uint256 pendingValue;
        uint256 updateTime;
    }

    struct Commitment {
        bytes32 hash;
        uint256 blockNumber;
    }
}
