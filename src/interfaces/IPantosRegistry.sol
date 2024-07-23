// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;
pragma abicoder v2;

import {PantosTypes} from "./PantosTypes.sol";

/**
 * @title Pantos Registry interface
 *
 * @notice The Pantos Registry connects the on-chain (Forwarder, tokens)
 * and off-chain (service nodes, validator nodes) components of the
 * Pantos multi-blockchain system.
 *
 * @dev The interface declares all Pantos hub events and functions for
 * service nodes, validator nodes, and the admin functions which are only
 * allowed to be called by the Pantos hub owner.
 * This excludes all the transafer related functions, served by a separate
 * interface.
 */
interface IPantosRegistry {
    event Paused(address account);

    event Unpaused(address account);

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

    /**
     * @notice Event that is emitted when a new blockchain is registered.
     *
     * @param blockchainId The id of the blockchain.
     */
    event BlockchainRegistered(uint256 blockchainId);

    /**
     * @notice Event that is emitted when an already registerd blockchain
     * is unregistered.
     *
     * @param blockchainId The id of the blockchain.
     */
    event BlockchainUnregistered(uint256 blockchainId);

    event BlockchainNameUpdated(uint256 blockchainId);

    event TokenRegistered(address token);

    event TokenUnregistered(address token);

    event ExternalTokenRegistered(address token, uint256 blockchainId);

    event ExternalTokenUnregistered(address token, uint256 blockchainId);

    /**
     * @notice Event that is emitted when a new service node is registered.
     *
     * @param serviceNode The address of the new service node.
     */
    event ServiceNodeRegistered(address serviceNode);

    /**
     * @notice Event that is emitted when a registered service node is
     * unregistered.
     *
     * @param serviceNode The address of the registered service node.
     */
    event ServiceNodeUnregistered(address serviceNode);

    /**
     * @notice Event that is emitted when a registered service node url is
     * updated.
     *
     * @param serviceNode The address of the registered service node.
     */
    event ServiceNodeUrlUpdated(address serviceNode);

    /**
     * @notice Event that is emitted when the unbonding period for the
     * service node deposit is updated.
     *
     * @param unbondingPeriodServiceNodeDeposit The new unbonding period
     * for the service node deposit (in seconds).
     */
    event UnbondingPeriodServiceNodeDepositUpdated(
        uint256 unbondingPeriodServiceNodeDeposit
    );

    /**
     * @notice Event that is emitted when the minimum service node
     * deposit is updated.
     *
     * @param minimumServiceNodeDeposit The new minimum service node
     * deposit.
     */
    event MinimumServiceNodeDepositUpdated(uint256 minimumServiceNodeDeposit);

    /**
     * @notice Event that is emitted when the minimum validator fee update
     * period is updated.
     *
     * @param minimumValidatorFeeUpdatePeriod The new minimum validator fee
     * update period.
     */
    event MinimumValidatorFeeUpdatePeriodUpdated(
        uint256 minimumValidatorFeeUpdatePeriod
    );

    /**
     * @notice Event that is emitted when validator fee is updated for a given
     * blockchain.
     * @param blockchainId The id of the blockchain.
     * @param oldFactor Old fee factor.
     * @param newFactor New fee factor.
     * @param validFrom The timestamp from which the fee factor becomes valid.
     */
    event ValidatorFeeUpdated(
        uint256 blockchainId,
        uint256 oldFactor,
        uint256 newFactor,
        uint256 validFrom
    );

    /**
     * @notice Pauses the Pantos Hub.
     *
     * @dev The function can only be called by the owner of the contract
     * and only if the contract is not paused.
     */
    function pause() external;

    /**
     * @notice Unpauses the Pantos Hub.
     *
     * @dev The function can only be called by the owner of the contract
     * and only if the contract is paused.
     */
    function unpause() external;

    /**
     * @notice Sets the Pantos Forwarder contract address.
     *
     * @param pantosForwarder The address of the Pantos Forwarder contract.
     *
     * @dev The function can only be called by the owner of the contract
     * and only if the contract is paused.
     */
    function setPantosForwarder(address pantosForwarder) external;

    /**
     * @notice Set the Pantos Token contract address.
     *
     * @param pantosToken The address of the Pantos Token contract.
     *
     * @dev The function can only be called by the owner of the contract
     * and only if the contract is paused.
     */
    function setPantosToken(address pantosToken) external;

    /**
     * @notice Update the primary validator node.
     *
     * @param primaryValidatorNodeAddress The address of the primary
     * validator node.
     *
     * @dev The function can only be called by the owner of the contract
     * and only if the contract is paused.
     */
    function setPrimaryValidatorNode(
        address primaryValidatorNodeAddress
    ) external;

    /**
     * @notice Used by the owner of the Pantos Hub contract to register a new
     * blockchain.
     *
     * @param blockchainId The id of the blockchain to be registered.
     * @param name The name of the blockchain to be registered.
     * @param feeFactor The fee factor to be used for that blockchain.
     * @param feeFactorValidFrom The timestamp from which the fee factor for
     * the new blockchain becomes valid.
     *
     * @dev The function can only be called by the Pantos Hub owner.
     */
    function registerBlockchain(
        uint256 blockchainId,
        string calldata name,
        uint256 feeFactor,
        uint256 feeFactorValidFrom
    ) external;

    /**
     * @notice Used by the owner of the Pantos Hub contract to unregister a
     * blockchain.
     *
     * @param blockchainId The id of the blockchain to be unregistered.
     */
    function unregisterBlockchain(uint256 blockchainId) external;

    /**
     * @notice Used by the owner of the Pantos Hub contract to update the name
     * of a registered blockchain.
     *
     * @param blockchainId The id of the blockchain to be updated.
     * @param name The new name of the blockchain.
     *
     * @dev The function can only be called by the Pantos Hub owner and if the
     * contract is paused.
     */
    function updateBlockchainName(
        uint256 blockchainId,
        string calldata name
    ) external;

    /**
     * @notice Used by the owner of the Pantos Hub contract to update the fee
     * factor of a registered blockchain.
     *
     * @param blockchainId The id of the blockchain for which the fee factor is
     * updated.
     * @param newFactor The new fee factor.
     * @param validFrom The timestamp from which the new fee factor becomes
     * valid.
     */
    function updateFeeFactor(
        uint256 blockchainId,
        uint256 newFactor,
        uint256 validFrom
    ) external;

    /**
     * @notice Used by the owner of the Pantos Hub contract to update
     * the unbonding period for the service node deposit.
     *
     * @param unbondingPeriodServiceNodeDeposit The new unbonding period
     * for the service node deposit (in seconds).
     *
     * @dev The function can only be called by the Pantos Hub owner.
     */
    function setUnbondingPeriodServiceNodeDeposit(
        uint256 unbondingPeriodServiceNodeDeposit
    ) external;

    /**
     * @notice Used by the owner of the Pantos Hub contract to update
     * the minimum service node deposit.
     *
     * @param minimumServiceNodeDeposit The new minimum service node
     * deposit.
     *
     * @dev The function can only be called by the Pantos Hub owner and
     * if the contract is paused.
     */
    function setMinimumServiceNodeDeposit(
        uint256 minimumServiceNodeDeposit
    ) external;

    /**
     * @notice Used by the owner of the Pantos Hub contract to update the
     * minimum validator fee update period.
     *
     * @param minimumValidatorFeeUpdatePeriod The new minimum validator
     * fee update period.
     */
    function setMinimumValidatorFeeUpdatePeriod(
        uint256 minimumValidatorFeeUpdatePeriod
    ) external;

    /**
     * @notice Allows a user to register a token with the Pantos Hub. The user
     * is required to be the owner of the token contract.
     *
     * @param token The address of the token contract.
     */
    function registerToken(address token) external;

    /**
     * @notice Allows a user to unregister a token with the Pantos Hub. The
     * user is required to be the owner of the token contract.
     *
     * @param token The address of the token contract.
     */
    function unregisterToken(address token) external;

    /**
     * @notice Allows a user to register an external token with the Pantos Hub.
     * The external token is a token contract on another blockchain.
     *
     * @param token The address of the token contract on the current blockchain.
     * @param blockchainId The id of the blockchain on which the external token
     * is deployed.
     * @param externalToken The address of the token contract on the external
     * blockchain.
     *
     * @dev The owner of a token residing on the current blockchain can register
     * an external token with the Pantos Hub. The external token is a token
     * contract on another blockchain. The external token is required to be
     * deployed on the blockchain with the given id. The external token is
     * required to be registered with the Pantos Hub on the blockchain with the
     * given id.
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
     * the blockchain on which the external token is deployed.
     *
     * @param token The address of the token contract on the current blockchain.
     * @param blockchainId The id of the blockchain on which the external token
     * is deployed.
     *
     * @dev The owner of a token residing on the current blockchain can
     * unregister an external token from the Pantos Hub. The external token is a
     * token contract on another blockchain. The external token is required to
     * be deployed on the blockchain with the given id. The external token is
     * required to be registered with the Pantos Hub on the blockchain with the
     * given id. Unregistering an external token from the Pantos Hub makes it
     * impossible to transfer tokens between the current blockchain and the
     * blockchain on which the external token is deployed.
     */
    function unregisterExternalToken(
        address token,
        uint256 blockchainId
    ) external;

    /**
     * @notice Used by a service node or its withdrawal address to
     * register a service node at the Pantos Hub.
     *
     * @param serviceNodeAddress The registered service node address.
     * @param url The URL under which the service node is reachable.
     * @param deposit The provided deposit in PAN.
     * @param withdrawalAddress The address where the deposit will be
     * returned to after the service node has been unregistered.
     *
     * @dev The function is only callable by a service node itself or its
     * withdrawal address. The service node is required to provide a URL
     * under which it is reachable. The service node is required to provide
     * a deposit in PAN in order to register. The deposit is required to be at
     * least the minimum service node deposit. The service node is required
     * to provide a withdrawal address where the deposit will be returned
     * after the unregistration and the elapse of the unbonding period.
     * The service node is required to be registered at the Pantos Hub in
     * order to be able to transfer tokens between blockchains.
     * If the service node was unregistered, this function can be called
     * only if the deposit has already been withdrawn. If the service node
     * intends to register again after an uregistration but the deposit has
     * not been withdrawn, use the cancelServiceNodeUnregistration function.
     */
    function registerServiceNode(
        address serviceNodeAddress,
        string calldata url,
        uint256 deposit,
        address withdrawalAddress
    ) external;

    /**
     * @notice Used by a service node or its withdrawal address to
     * unregister a service node from the Pantos Hub.
     *
     * @param serviceNodeAddress The address of the service node which is
     * unregistered.
     *
     * @dev The function is only callable by a service node itself or its
     * withdrawal address. The service node is required to be registered in
     * the Pantos Hub in order to be able to transfer tokens between
     * blockchains. Unregistering a service node from the Pantos Hub makes
     * it impossible to transfer tokens between blockchains using the
     * service node. The deposit of the service node can be withdrawn after
     * the elapse of the unbonding period by calling the
     * withdrawServiceNodeDeposit function at the PantosHub.
     */
    function unregisterServiceNode(address serviceNodeAddress) external;

    /**
     * @notice Used by a service node or its withdrawal address to
     * withdraw the deposit from the Pantos Hub.
     *
     * @param serviceNodeAddress The address of the service node which
     * wants to withdraw its deposit.
     *
     * @dev The function is only callable by a service node itself or its
     * withdrawal address. The deposit can be withdrawn only if the unbonding
     * period has elapsed. The unbonding period is the minimum time that
     * must pass between the unregistration of the service node and the
     * withdrawal of the deposit.
     */
    function withdrawServiceNodeDeposit(address serviceNodeAddress) external;

    /**
     * @notice Used by a service node or its withdrawal address to cancel
     * the unregistration from the PantosHub.
     *
     * @param serviceNodeAddress The address of the service node to cancel
     * the unregistration for.
     *
     * @dev The function is only callable by a service node itself or its
     * withdrawal address. A service node might need to have its unregistration
     * cancelled if a new registration is required before the unbondoing
     * period would elapse.
     */
    function cancelServiceNodeUnregistration(
        address serviceNodeAddress
    ) external;

    /**
     * @notice Increase a service node's deposit at the Pantos Hub.
     *
     * @param serviceNodeAddress The address of the service node which
     * will have its deposit increased.
     * @param deposit The amount that will be added to the current
     * deposit of the service node.
     *
     * @dev The function is only callable by an active service node
     * itself or the account of its withdrawal address.
     */
    function increaseServiceNodeDeposit(
        address serviceNodeAddress,
        uint256 deposit
    ) external;

    /**
     * @notice Decrease a service node's deposit at the Pantos Hub.
     *
     * @param serviceNodeAddress The address of the service node which
     * will have its deposit decreased.
     * @param deposit The amount that will be subtracted from the
     * current deposit of the service node.
     *
     * @dev The function is only callable by an active service node
     * itself or the account of its withdrawal address.
     */
    function decreaseServiceNodeDeposit(
        address serviceNodeAddress,
        uint256 deposit
    ) external;

    /**
     * @notice Used by a service node to update its url in the Pantos Hub.
     *
     * @param url The new url as string.
     *
     * @dev The function is only callable by a service node itself.
     * The service node is required to provide a new unique url under which it
     * is reachable.
     */
    function updateServiceNodeUrl(string calldata url) external;

    /**
     * @notice Returns the address of the Pantos Forwarder contract.
     *
     * @return The address of the Pantos Forwarder contract.
     */
    function getPantosForwarder() external view returns (address);

    /**
     * @notice Returns the address of the Pantos Token contract.
     *
     * @return The address of the Pantos Token contract.
     */
    function getPantosToken() external view returns (address);

    /**
     * @return The address of the primary validator node.
     */
    function getPrimaryValidatorNode() external view returns (address);

    /**
     * @notice Returns the number of blockchains registered with the Pantos Hub.
     *
     * @return The number as uint of blockchains registered with the Pantos Hub.
     */
    function getNumberBlockchains() external view returns (uint256);

    /**
     * @notice Returns the number of active blockchains registered with the
     * Pantos Hub.
     *
     * @return The number as uint of active blockchains registered with the
     * Pantos Hub.
     */
    function getNumberActiveBlockchains() external view returns (uint256);

    /**
     * @notice Returns the blockchain id of the current blockchain.
     *
     * @return The blockchain id as unit of the current blockchain.
     */
    function getCurrentBlockchainId() external view returns (uint256);

    /**
     * @notice Returns a blockchain record for a given blockchain id.
     *
     * @param blockchainId The id of the blockchain.
     *
     * @return The blockchain record for the given blockchain id.
     *
     * @dev More information about the blockchain record can be found at
     * {PantosTypes-BlockchainRecord}.
     */
    function getBlockchainRecord(
        uint256 blockchainId
    ) external view returns (PantosTypes.BlockchainRecord memory);

    /**
     * @notice Returns the minimum deposit required to register a service node
     * at the Pantos Hub.
     *
     * @return The minimum required deposit to register a service node at the
     * Pantos Hub.
     */
    function getMinimumServiceNodeDeposit() external view returns (uint256);

    /**
     * @notice Returns the unbonding period of the service node deposit
     * (in seconds).
     *
     * @return The unbonding period of the service node deposit.
     */
    function getUnbondingPeriodServiceNodeDeposit()
        external
        view
        returns (uint256);

    /**
     * @notice Returns a list of all tokens registered in the Pantos Hub which
     * are also deployed on the same blockchain as this Pantos Hub.
     *
     * @return A list of addresses of tokens registered in the Pantos Hub.
     */
    function getTokens() external view returns (address[] memory);

    /**
     * @notice Returns a token record for a given token address.
     *
     * @param token The address of a registered token for which a token record
     * is requested.
     *
     * @return A TokenRecord data structure.
     *
     * @dev More information about the TokenRecord data structure can be found
     * at {PantosTypes-TokenRecord}.
     */
    function getTokenRecord(
        address token
    ) external view returns (PantosTypes.TokenRecord memory);

    /**
     * @notice Returns a external token record for a external token under the
     * given token address and blockchain id.
     *
     * @param token The address of the token registered in the Pantos Hub and
     * being deployed on the same chain as the Pantos Hub.
     * @param blockchainId The blockchain id of a different blockchain on which
     * the external token is deployed too.
     *
     * @return A ExternalTokenRecord data structure.
     *
     * @dev More information about the ExternalTokenRecord data structure can
     * be found {PantosTypes-ExternalTokenRecord}.
     */
    function getExternalTokenRecord(
        address token,
        uint256 blockchainId
    ) external view returns (PantosTypes.ExternalTokenRecord memory);

    /**
     * @notice Returns a list of registered service nodes.
     *
     * @return A list of addresses of registered services nodes.
     */
    function getServiceNodes() external view returns (address[] memory);

    /**
     * @notice Returns a service node record for a given service node address.
     *
     * @param serviceNode The address of a registered service node.
     *
     * @return A ServiceNodeRecord data structure.
     *
     * @dev More information about the ServiceNodeRecord data structure can be
     * found at {PantosTypes-ServiceNodeRecord}.
     */
    function getServiceNodeRecord(
        address serviceNode
    ) external view returns (PantosTypes.ServiceNodeRecord memory);

    /**
     * @notice Returns a fee record for a specific blockchain id.
     *
     * @param blockchainId The blockchain id for which the fee record is
     * requested.
     *
     * @return A FeeRecord data structure.
     *
     * @dev More information about the FeeRecord data structure can be found at
     * {PantosTypes-FeeRecord}.
     */
    function getValidatorFeeRecord(
        uint256 blockchainId
    ) external view returns (PantosTypes.ValidatorFeeRecord memory);

    /**
     * @notice Returns the fee update period in uint.
     *
     * @return The minimum validator fee update period as uint.
     *
     * @dev The minimum validator fee update period is the minimum
     * amount of time in seconds between two fee updates for a specific
     * blockchain.
     */
    function getMinimumValidatorFeeUpdatePeriod()
        external
        view
        returns (uint256);

    /**
     * @notice Takes the service node address and returns whether the
     * service node is in the unbonding period or not.
     *
     * @param serviceNodeAddress The service node address to be checked.
     *
     * @return True if the service node is in the unbonding period,
     * false otherwise.
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
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() external view returns (bool);
}
