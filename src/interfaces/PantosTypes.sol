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
        uint256 stake;
    }

    struct ExternalTokenRecord {
        bool active;
        string externalToken; // External token address
    }

    struct ServiceNodeRecord {
        bool active;
        string url;
        uint256 freeStake;
        uint256 lockedStake;
        address unstakingAddress;
        uint256 unregisterTime;
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

    struct ValidatorFeeRecord {
        uint256 oldFactor;
        uint256 newFactor;
        uint256 validFrom;
    }
}
