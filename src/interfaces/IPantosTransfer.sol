// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.23;
pragma abicoder v2;

import {PantosTypes} from "./PantosTypes.sol";

/**
 * @title Pantos Transfer interface
 *
 * @notice All transfer-related functionality of the Pantos Hub.
 *
 * @dev The interface declares all Pantos Hub events and functions related
 * to token transfers.
 */
interface IPantosTransfer {
    event Transfer(
        uint256 transferId,
        address sender,
        address recipient,
        address token,
        uint256 amount,
        uint256 fee,
        address serviceNode
    );

    event TransferFrom(
        uint256 sourceTransferId,
        uint256 destinationBlockchainId,
        address sender,
        string recipient,
        address sourceToken,
        string destinationToken,
        uint256 amount,
        uint256 fee,
        address serviceNode
    );

    event TransferTo(
        uint256 sourceBlockchainId,
        uint256 sourceTransferId,
        string sourceTransactionId,
        uint256 destinationTransferId,
        string sender,
        address recipient,
        string sourceToken,
        address destinationToken,
        uint256 amount,
        uint256 nonce,
        address[] signerAddresses,
        bytes[] signatures
    );

    /**
     * @notice Transfers token between from a sender to a recipient on the
     * current blockchain. This function can only be called by an active
     * service node
     *
     * @param request The TransferRequest data structure containing the
     * transfer request on the current blockchain
     * @param signature Signature over the transfer request from the sender
     *
     * @return The id of the transfer
     *
     * @dev The function is only callable by an active service node. The
     * transfer request is required to be valid and signed by the sender of
     * the tokens. More information about the TransferRequest data structure
     * can be found at {PantosTypes-TransferRequest}
     */
    function transfer(
        PantosTypes.TransferRequest calldata request,
        bytes memory signature
    ) external returns (uint256);

    /**
     * @notice Sender initiates a token transfer from the current blockchain to
     * a recipient on another blockchain. This function can only be called by
     * an active service node
     *
     * @param request The TransferFromRequest data structure containing the
     * transfer request across blockchains
     * @param signature Signature over the transfer request from the sender
     *
     * @return The id of the transfer
     *
     * @dev The function is only callable by an active service node. The
     * transfer request is required to be valid and signed by the sender of
     * the tokens. The senders tokens are burnt on the current blockchain.
     * More information about the TransferFromRequest data structure can be
     * found at {PantosTypes-TransferFromRequest}
     */
    function transferFrom(
        PantosTypes.TransferFromRequest calldata request,
        bytes memory signature
    ) external returns (uint256);

    /**
     * @notice Second step of a cross-blockchain token transfer. The function
     * is called by the Pantos Validator on the destination blockchain and
     * the tokens are minted into the recipients wallet.
     *
     * @param request The TransferToRequest data structure containing the
     * transfer request across blockchains.
     * @param signerAddresses The addresses of the validator nodes that
     * signed the transfer (must be ordered from the lowest to the
     * highest address).
     * @param signatures The signatures of the validator nodes (each
     * signature must be in the same array position as the corresponding
     * signer address).
     *
     * @return The ID of the transfer.
     *
     * @dev The function is only callable by the Pantos Validator on the
     * destination blockchain. The transfer request is required to be valid and
     * signed by the Pantos Validator. The tokens are minted into the
     * recipients address on the destination blockchain. More information about
     * the TransferToRequest data structure can be found at
     * {PantosTypes-TransferToRequest}.
     */
    function transferTo(
        PantosTypes.TransferToRequest memory request,
        address[] memory signerAddresses,
        bytes[] memory signatures
    ) external returns (uint256);

    /**
     * @notice Takes a sender address and a nonce and returns whether the nonce
     * is valid for the sender or not
     *
     * @param sender The address of the sender
     * @param nonce The nonce to be checked
     *
     * @return True if the nonce is valid, false otherwise
     */
    function isValidSenderNonce(
        address sender,
        uint256 nonce
    ) external view returns (bool);

    /**
     * @notice Verifies if a TransferRequest data structure is valid or not
     *
     * @param request The TransferRequest data structure to be checked
     * @param signature The signature over the TransferRequest data structure
     *
     * @dev The function reverts if the TransferRequest data structure is not
     * valid
     */
    function verifyTransfer(
        PantosTypes.TransferRequest calldata request,
        bytes memory signature
    ) external view;

    /**
     * @notice Verifies if a TransferFromRequest data structure is valid or not
     *
     * @param request The TransferFromRequest data structure to be checked
     * @param signature The signature over the TransferFromRequest data
     *
     * @dev The function reverts if the TransferFromRequest data structure is
     * not valid
     */
    function verifyTransferFrom(
        PantosTypes.TransferFromRequest calldata request,
        bytes memory signature
    ) external view;

    /**
     * @notice Verifies if a TransferToRequest data structure is valid or not.
     *
     * @param request The TransferToRequest data structure to be checked.
     * @param signerAddresses The addresses of the validator nodes that
     * signed the transfer (must be ordered from the lowest to the
     * highest address).
     * @param signatures The signatures of the validator nodes (each
     * signature must be in the same array position as the corresponding
     * signer address).
     *
     * @dev The function reverts if the TransferToRequest data structure is not
     * valid.
     */
    function verifyTransferTo(
        PantosTypes.TransferToRequest memory request,
        address[] memory signerAddresses,
        bytes[] memory signatures
    ) external view;

    /**
     * @dev This function returns a transfer id to be used in next transfer.
     */
    function getNextTransferId() external view returns (uint256);
}
