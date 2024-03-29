// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.23;
pragma abicoder v2;

import "./PantosTypes.sol";

/**
 * @title Pantos Hub interface
 *
 * @notice The Pantos hub connects all on-chain (forwarder, tokens) and
 * off-chain (clients, service nodes, validator nodes) components of the
 * Pantos multi-blockchain system
 *
 * @dev The interface declares all Pantos hub events and functions for token
 * owners, clients, service nodes, validator nodes, and other interested
 * external users, excluding the functions which are only allowed to be called
 * by the Pantos hub owner
 */
interface IPantosHub {
    event PantosForwarderSet(address pantosForwarder);

    event PantosTokenSet(address pantosToken);

    /**
     * @notice Event that is emitted when the primary validator node is
     * updated.
     *
     * @param primaryValidatorNodeAddress The address of the primary
     * validator node.
     */
    event PrimaryValidatorNodeUpdated(address primaryValidatorNodeAddress);

    event BlockchainRegistered(uint256 blockchainId);

    event BlockchainUnregistered(uint256 blockchainId);

    event BlockchainNameUpdated(uint256 blockchainId);

    event TokenRegistered(address token);

    event TokenUnregistered(address token);

    event ExternalTokenRegistered(address token, uint256 blockchainId);

    event ExternalTokenUnregistered(address token, uint256 blockchainId);

    event ServiceNodeRegistered(address serviceNode);

    event ServiceNodeUnregistered(address serviceNode);

    event ServiceNodeUrlUpdated(address serviceNode);

    /**
     * @notice Event that is emitted when the minimum token stake is
     * updated.
     *
     * @param minimumTokenStake The new minimum token stake.
     */
    event MinimumTokenStakeUpdated(uint256 minimumTokenStake);

    /**
     * @notice Event that is emitted when the unbonding period for the
     * service node stake is updated.
     *
     * @param unbondingPeriodServiceNodeStake The new unbonding period
     * for the service node stake (in seconds).
     */
    event UnbondingPeriodServiceNodeStakeUpdated(
        uint256 unbondingPeriodServiceNodeStake
    );

    /**
     * @notice Event that is emitted when the minimum service node stake
     * is updated.
     *
     * @param minimumServiceNodeStake The new minimum service node
     * stake.
     */
    event MinimumServiceNodeStakeUpdated(uint256 minimumServiceNodeStake);

    event MinimumValidatorFeeUpdatePeriodUpdated(
        uint256 minimumValidatorFeeUpdatePeriod
    );

    event ValidatorFeeUpdated(
        uint256 blockchainId,
        uint256 oldFactor,
        uint256 newFactor,
        uint256 validFrom
    );

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
     * @notice Allows a user to register a token with the Pantos Hub. The user
     * is required to be the owner of the token contract
     *
     * @param token The address of the token contract
     * @param stake The amount of tokens to stake
     */
    function registerToken(address token, uint256 stake) external;

    /**
     * @notice Allows a user to unregister a token with the Pantos Hub. The
     * user is required to be the owner of the token contract
     *
     * @param token The address of the token contract
     */
    function unregisterToken(address token) external;

    /**
     * @notice Allows a user to increase the stake of a token at the Pantos Hub.
     * The user is required to be the owner of the token contract.
     *
     * @param token The address of the token contract
     * @param stake The additional stake that will be added to the current
     * one of the token contract
     */
    function increaseTokenStake(address token, uint256 stake) external;

    /**
     * @notice Allows a user to decrease the stake of a token at the Pantos Hub.
     * The user is required to be the owner of the token contract.
     *
     * @param token The address of the token contract
     * @param stake The reduced stake that will be subtracted from the current
     * one of the token contract
     */
    function decreaseTokenStake(address token, uint256 stake) external;

    /**
     * @notice Allows a user to register an external token with the Pantos Hub.
     * The external token is a token contract on another blockchain
     *
     * @param token The address of the token contract on the current blockchain.
     * @param blockchainId The id of the blockchain on which the external token
     * is deployed
     * @param externalToken The address of the token contract on the external
     * blockchain
     *
     * @dev The owner of a token residing on the current blockchain can register
     * an external token with the Pantos Hub. The external token is a token
     * contract on another blockchain. The external token is required to be
     * deployed on the blockchain with the given id. The external token is
     * required to be registered with the Pantos Hub on the blockchain with the
     * given id
     */
    function registerExternalToken(
        address token,
        uint256 blockchainId,
        string calldata externalToken
    ) external;

    /**
     * @notice Allows a user to unregister an external token from the Pantos Hub
     * on the current blockchain. The external token is a token contract on
     * another blockchain. Unregistering an external token from the Pantos Hub
     * makes it impossible to transfer tokens between the current blockchain and
     * the blockchain on which the external token is deployed
     *
     * @param token The address of the token contract on the current blockchain
     * @param blockchainId The id of the blockchain on which the external token
     * is deployed
     *
     * @dev The owner of a token residing on the current blockchain can
     * unregister an external token from the Pantos Hub. The external token is a
     * token contract on another blockchain. The external token is required to
     * be deployed on the blockchain with the given id. The external token is
     * required to be registered with the Pantos Hub on the blockchain with the
     * given id. Unregistering an external token from the Pantos Hub makes it
     * impossible to transfer tokens between the current blockchain and the
     * blockchain on which the external token is deployed
     */
    function unregisterExternalToken(
        address token,
        uint256 blockchainId
    ) external;

    /**
     * @notice Used by a service node or its unstaking address to register
     * a service node in the Pantos Hub
     *
     * @param serviceNodeAddress The registered service node address
     * @param url The url under which the service node is reachable
     * @param stake The required stake in Pan in order to register
     * @param unstakingAddress The address where the stake will be returned
     * after the service node is unregistered.
     *
     * @dev The function is only callable by a service node itself or its
     * unstaking address. The service node is required to provide a url
     * under which it is reachable. The service node is required to provide
     * a stake in Pan in order to register. The stake is required to be at
     * least the minimum service node stake. The service node is required
     * to provide an unstaking address where the token stake will be returned
     * after the unregistration and the elapse of the unbonding period.
     * The service node is required to be registered in the Pantos Hub in
     * order to be able to transfer tokens between blockchains.
     * If the service node was unregistered, this function can be called
     * only if the stake has already been withdrawn. If the service node
     * intends to register again after an uregistration but the stake has
     * not been withdrawn, use the cancelServiceNodeUnregistration function.
     */
    function registerServiceNode(
        address serviceNodeAddress,
        string calldata url,
        uint256 stake,
        address unstakingAddress
    ) external;

    /**
     * @notice Used by a service node or its unstaking address to unregister
     * a service node from the Pantos Hub
     *
     * @param serviceNodeAddress The address of the service node which is
     * unregistered
     *
     * @dev The function is only callable by a service node itself or its
     * unstaking address. The service node is required to be registered in
     * the Pantos Hub in order to be able to transfer tokens between
     * blockchains. Unregistering a service node from the Pantos Hub makes
     * it impossible to transfer tokens between blockchains using the
     * service node. The stake of the service node ca be withdrawn after
     * the elapse of the unbonding period by calling the
     * withdrawServiceNodeStake function at the PantosHub.
     */
    function unregisterServiceNode(address serviceNodeAddress) external;

    /**
     * @notice Used by a service node or its unstaking address to withdraw
     * the stake from the Pantos Hub
     *
     * @param serviceNodeAddress The address of the service node which plan
     * to withdraw the stake
     *
     * @dev The function is only callable by a service node itself or its
     * unstaking address. The stake can be withdrawn only if the unbonding
     * period has elapsed. The unbonding period is the minimum time that
     * must pass between the unregistration of the service node and the
     * withdrawal of the stake.
     */
    function withdrawServiceNodeStake(address serviceNodeAddress) external;

    /**
     * @notice Used by a service node or its unstaking address to cancel
     * the unregistration from the PantosHub
     *
     * @param serviceNodeAddress The address of the service node to cancel
     * the unregistration for
     *
     * @dev The function is only callable by a service node itself or its
     * unstaking address. A service node might need to have its unregistration
     * cancelled if a new registration is required before the unbondoing
     * period would elapse.
     */
    function cancelServiceNodeUnregistration(
        address serviceNodeAddress
    ) external;

    /**
     * @notice Used by a service node to increase its stake at the Pantos Hub
     * The function is only callable by an active service node itself.
     *
     * @param serviceNodeAddress The address of the service node which will
     * have the stake increased
     * @param stake The additional stake that will be added to the current
     * one of the service node
     */
    function increaseServiceNodeStake(
        address serviceNodeAddress,
        uint256 stake
    ) external;

    /**
     * @notice Used by a service node to decrease its stake at the Pantos Hub.
     * The function is only callable by an active service node itself.
     *
     * @param serviceNodeAddress The address of the service node which will
     * have the stake decreased
     * @param stake The reduced stake that will be subtracted from the current
     * one of the service node
     */
    function decreaseServiceNodeStake(
        address serviceNodeAddress,
        uint256 stake
    ) external;

    /**
     * @notice Used by a service node to update its url in the Pantos Hub
     *
     * @param url The new url as string
     *
     * @dev The function is only callable by a service node itself.
     * The service node is required to provide a new unique url under which it
     * is reachable
     */
    function updateServiceNodeUrl(string calldata url) external;

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
     * @notice Returns the address of the Pantos Forwarder contract
     *
     * @return The address of the Pantos Forwarder contract
     */
    function getPantosForwarder() external view returns (address);

    /**
     * @notice Returns the address of the Pantos Token contract
     *
     * @return The address of the Pantos Token contract
     */
    function getPantosToken() external view returns (address);

    /**
     * @return The address of the primary validator node.
     */
    function getPrimaryValidatorNode() external view returns (address);

    /**
     * @notice Returns the number of blockchains registered with the Pantos Hub
     *
     * @return The number as uint of blockchains registered with the Pantos Hub
     */
    function getNumberBlockchains() external view returns (uint256);

    /**
     * @notice Returns the number of active blockchains registered with the
     * Pantos Hub
     *
     * @return The number as uint of active blockchains registered with the
     * Pantos Hub
     */
    function getNumberActiveBlockchains() external view returns (uint256);

    /**
     * @notice Returns the blockchain id of the current blockchain
     *
     * @return The blockchain id as unit of the current blockchain
     */
    function getCurrentBlockchainId() external view returns (uint256);

    /**
     * @notice Returns a blockchain record for a given blockchain id
     *
     * @param blockchainId The id of the blockchain
     *
     * @return The blockchain record for the given blockchain id
     *
     * @dev More information about the blockchain record can be found at
     * {PantosTypes-BlockchainRecord}
     */
    function getBlockchainRecord(
        uint256 blockchainId
    ) external view returns (PantosTypes.BlockchainRecord memory);

    /**
     * @notice Returns the minimum stake required to register a token in the
     * Pantos Hub
     *
     * @return The minimum required stake to register a token in the Pantos
     * Hub as uint
     */
    function getMinimumTokenStake() external view returns (uint256);

    /**
     * @notice Returns the minimum stake required to register a service node
     * in the Pantos Hub
     *
     * @return The minimum required stake to register a service node in the
     * Pantos Hub
     */
    function getMinimumServiceNodeStake() external view returns (uint256);

    /**
     * @notice Returns the unbonding period of the service node stake
     * (in seconds)
     *
     * @return The unbonding period of the service node stake
     */
    function getUnbondingPeriodServiceNodeStake()
        external
        view
        returns (uint256);

    /**
     * @notice Returns a list of all tokens registered in the Pantos Hub which
     * are also deployed on the same blockchain as this Pantos Hub
     *
     * @return A list of addresses of tokens registered in the Pantos Hub
     */
    function getTokens() external view returns (address[] memory);

    /**
     * @notice Returns a token record for a given token address
     *
     * @param token The address of a registered token for which a token record
     * is requested
     *
     * @return A TokenRecord data structure
     *
     * @dev More information about the TokenRecord data structure can be found
     * at {PantosTypes-TokenRecord}
     */
    function getTokenRecord(
        address token
    ) external view returns (PantosTypes.TokenRecord memory);

    /**
     * @notice Returns a external token record for a external token under the
     * given token address and blockchain id
     *
     * @param token The address of the token registered in the Pantos Hub and
     * being deployed on the same chain as the Pantos Hub.
     * @param blockchainId The blockchain id of a different blockchain on which
     * the external token is deployed too
     *
     * @return A ExternalTokenRecord data structure
     *
     * @dev More information about the ExternalTokenRecord data structure can
     * be found {PantosTypes-ExternalTokenRecord}
     */
    function getExternalTokenRecord(
        address token,
        uint256 blockchainId
    ) external view returns (PantosTypes.ExternalTokenRecord memory);

    /**
     * @notice Returns a list of registered service nodes
     *
     * @return A list of addresses of registered services nodes
     */
    function getServiceNodes() external view returns (address[] memory);

    /**
     * @notice Returns a service node record for a given service node address
     *
     * @param serviceNode The address of a registered service node
     *
     * @return A ServiceNodeRecord data structure
     *
     * @dev More information about the ServiceNodeRecord data structure can be
     * found at {PantosTypes-ServiceNodeRecord}
     */
    function getServiceNodeRecord(
        address serviceNode
    ) external view returns (PantosTypes.ServiceNodeRecord memory);

    /**
     * @notice Returns a fee record for a specific blockchain id
     *
     * @param blockchainId The blockchain id for which the fee record is
     * requested
     *
     * @return A FeeRecord data structure
     *
     * @dev More information about the FeeRecord data structure can be found at
     * {PantosTypes-FeeRecord}
     */
    function getValidatorFeeRecord(
        uint256 blockchainId
    ) external view returns (PantosTypes.ValidatorFeeRecord memory);

    /**
     * @notice Returns the fee update period in uint
     *
     * @return The minimum validator fee update period as uint
     *
     * @dev The minimum validator fee update period is the minimum
     * amount of time in seconds between two fee updates for a specific
     * blockchain
     */
    function getMinimumValidatorFeeUpdatePeriod()
        external
        view
        returns (uint256);

    /**
     * @notice Takes the service node address and returns whether the
     * service node is in the unbonding period or not.
     *
     * @param serviceNodeAddress The service node address to be checked
     *
     * @return True if the service node is in the unbonding period,
     * false otherwise
     */
    function isServiceNodeInTheUnbondingPeriod(
        address serviceNodeAddress
    ) external view returns (bool);

    /**
     * @notice Check if a given nonce is a valid (i.e. not yet used)
     * validator node nonce.
     *
     * @param nonce The nonce to be checked.
     *
     * @return True if the nonce is valid.
     */
    function isValidValidatorNodeNonce(
        uint256 nonce
    ) external view returns (bool);

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
}
