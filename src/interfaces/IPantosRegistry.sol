// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {PantosTypes} from "./PantosTypes.sol";

/**
 * @title Pantos Registry interface
 *
 * @notice The Pantos Registry connects the on-chain (Forwarder, tokens)
 * and off-chain (service nodes, validator nodes) components of the
 * Pantos multi-blockchain system.
 *
 * @dev The interface declares all Pantos hub events and functions for
 * service nodes, validator nodes, Pantos roles, and other interested
 * external users.
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
     * @notice Event that is emitted when a new blockchain is
     * registered.
     *
     * @param blockchainId The ID of the new blockchain.
     * @param validatorFeeFactor The validator fee factor of the new
     * blockchain.
     */
    event BlockchainRegistered(
        uint256 blockchainId,
        uint256 validatorFeeFactor
    );

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
     * @notice Event that is emitted when an update of the unbonding
     * period for service node deposits is initiated.
     *
     * @param newUnbondingPeriodServiceNodeDeposit The new unbonding
     * period (in seconds) for service node deposits.
     * @param earliestUpdateTime The earliest time when the update can
     * be executed.
     */
    event UnbondingPeriodServiceNodeDepositUpdateInitiated(
        uint256 newUnbondingPeriodServiceNodeDeposit,
        uint256 earliestUpdateTime
    );

    /**
     * @notice Event that is emitted when an update of the unbonding
     * period for service node deposits is executed.
     *
     * @param newUnbondingPeriodServiceNodeDeposit The new unbonding
     * period (in seconds) for service node deposits.
     */
    event UnbondingPeriodServiceNodeDepositUpdateExecuted(
        uint256 newUnbondingPeriodServiceNodeDeposit
    );

    /**
     * @notice Event that is emitted when an update of the minimum
     * service node deposit is initiated.
     *
     * @param newMinimumServiceNodeDeposit The new minimum service node
     * deposit.
     * @param earliestUpdateTime The earliest time when the update can
     * be executed.
     */
    event MinimumServiceNodeDepositUpdateInitiated(
        uint256 newMinimumServiceNodeDeposit,
        uint256 earliestUpdateTime
    );

    /**
     * @notice Event that is emitted when an update of the minimum
     * service node deposit is executed.
     *
     * @param newMinimumServiceNodeDeposit The new minimum service node
     * deposit.
     */
    event MinimumServiceNodeDepositUpdateExecuted(
        uint256 newMinimumServiceNodeDeposit
    );

    /**
     * @notice Event that is emitted when an update of a validator fee
     * factor is initiated.
     *
     * @param blockchainId The ID of the blockchain the validator fee
     * factor is updated for.
     * @param newValidatorFeeFactor The new validator fee factor.
     * @param earliestUpdateTime The earliest time when the update can
     * be executed.
     */
    event ValidatorFeeFactorUpdateInitiated(
        uint256 blockchainId,
        uint256 newValidatorFeeFactor,
        uint256 earliestUpdateTime
    );

    /**
     * @notice Event that is emitted when an update of a validator fee
     * factor is executed.
     *
     * @param blockchainId The ID of the blockchain the validator fee
     * factor is updated for.
     * @param newValidatorFeeFactor The new validator fee factor.
     */
    event ValidatorFeeFactorUpdateExecuted(
        uint256 blockchainId,
        uint256 newValidatorFeeFactor
    );

    /**
     * @notice Event that is emitted when an update of the parameter
     * update delay is initiated.
     *
     * @param newParameterUpdateDelay The new parameter update delay.
     * @param earliestUpdateTime The earliest time when the update can
     * be executed.
     */
    event ParameterUpdateDelayUpdateInitiated(
        uint256 newParameterUpdateDelay,
        uint256 earliestUpdateTime
    );

    /**
     * @notice Event that is emitted when an update of the parameter
     * update delay is executed.
     *
     * @param newParameterUpdateDelay The new parameter update delay.
     */
    event ParameterUpdateDelayUpdateExecuted(uint256 newParameterUpdateDelay);

    /**
     * @notice Pauses the Pantos Hub.
     *
     * @dev The function can only be called by the pauser role
     * and only if the contract is not paused.
     */
    function pause() external;

    /**
     * @notice Unpauses the Pantos Hub.
     *
     * @dev The function can only be called by the super critical ops role
     * and only if the contract is paused.
     */
    function unpause() external;

    /**
     * @notice Sets the Pantos Forwarder contract address.
     *
     * @param pantosForwarder The address of the Pantos Forwarder contract.
     *
     * @dev The function can only be called by the super critical ops role
     * and only if the contract is paused.
     */
    function setPantosForwarder(address pantosForwarder) external;

    /**
     * @notice Set the Pantos Token contract address.
     *
     * @param pantosToken The address of the Pantos Token contract.
     *
     * @dev The function can only be called by the deployer role
     * and only if the contract is paused.
     */
    function setPantosToken(address pantosToken) external;

    /**
     * @notice Update the primary validator node.
     *
     * @param primaryValidatorNodeAddress The address of the primary
     * validator node.
     *
     * @dev The function can only be called by the super critical ops role
     * and only if the contract is paused.
     */
    function setPrimaryValidatorNode(
        address primaryValidatorNodeAddress
    ) external;

    /**
     * @notice Used by the super critical ops role to register a new
     * blockchain.
     *
     * @param blockchainId The ID of the new blockchain.
     * @param name The name of the new blockchain.
     * @param validatorFeeFactor The validator fee factor of the new
     * blockchain.
     *
     * @dev The function can only be called by the super critical ops role.
     */
    function registerBlockchain(
        uint256 blockchainId,
        string calldata name,
        uint256 validatorFeeFactor
    ) external;

    /**
     * @notice Used by the super critical ops role to unregister a
     * blockchain.
     *
     * @param blockchainId The id of the blockchain to be unregistered.
     */
    function unregisterBlockchain(uint256 blockchainId) external;

    /**
     * @notice Used by the medium critical ops role to update the name
     * of a registered blockchain.
     *
     * @param blockchainId The id of the blockchain to be updated.
     * @param name The new name of the blockchain.
     *
     * @dev The function can only be called by the medium critical ops role
     * and if the contract is paused.
     */
    function updateBlockchainName(
        uint256 blockchainId,
        string calldata name
    ) external;

    /**
     * @notice Initiate an update of a validator fee factor.
     *
     * @param blockchainId The ID of the blockchain the validator fee
     * factor is updated for.
     * @param newValidatorFeeFactor The new validator fee factor.
     *
     * @dev The function can only be called by the medium critical ops role.
     */
    function initiateValidatorFeeFactorUpdate(
        uint256 blockchainId,
        uint256 newValidatorFeeFactor
    ) external;

    /**
     * @notice Execute an update of a validator fee factor.
     *
     * @param blockchainId The ID of the blockchain the validator fee
     * factor is updated for.
     *
     * @dev The function can only be called when the time delay after
     * an initiated update has elapsed.
     */
    function executeValidatorFeeFactorUpdate(uint256 blockchainId) external;

    /**
     * @notice Initiate an update of the unbonding period for service
     * node deposits.
     *
     * @param newUnbondingPeriodServiceNodeDeposit The new unbonding
     * period (in seconds) for service node deposits.
     *
     * @dev The function can only be called by the medium critical ops role.
     */
    function initiateUnbondingPeriodServiceNodeDepositUpdate(
        uint256 newUnbondingPeriodServiceNodeDeposit
    ) external;

    /**
     * @notice Execute an update of the unbonding period for service
     * node deposits.
     *
     * @dev The function can only be called when the time delay after
     * an initiated update has elapsed.
     */
    function executeUnbondingPeriodServiceNodeDepositUpdate() external;

    /**
     * @notice Initiate an update of the minimum service node deposit.
     *
     * @param newMinimumServiceNodeDeposit The new minimum service node
     * deposit.
     *
     * @dev The function can only be called by the medium critical ops role.
     */
    function initiateMinimumServiceNodeDepositUpdate(
        uint256 newMinimumServiceNodeDeposit
    ) external;

    /**
     * @notice Execute an update of the minimum service node deposit.
     *
     * @dev The function can only be called when the time delay after
     * an initiated update has elapsed.
     */
    function executeMinimumServiceNodeDepositUpdate() external;

    /**
     * @notice Initiate an update of the parameter update delay.
     *
     * @param newParameterUpdateDelay The new parameter update delay.
     *
     * @dev The function can only be called by the medium critical ops role.
     */
    function initiateParameterUpdateDelayUpdate(
        uint256 newParameterUpdateDelay
    ) external;

    /**
     * @notice Execute an update of the parameter update delay.
     *
     * @dev The function can only be called when the time delay after
     * an initiated update has elapsed.
     */
    function executeParameterUpdateDelayUpdate() external;

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
     * @return The current minimum required deposit to register a
     * service node at the Pantos Hub.
     */
    function getCurrentMinimumServiceNodeDeposit()
        external
        view
        returns (uint256);

    /**
     * @return All data related to the minimum required deposit to
     * register a service node at the Pantos Hub.
     */
    function getMinimumServiceNodeDeposit()
        external
        view
        returns (PantosTypes.UpdatableUint256 memory);

    /**
     * @return The current unbonding period (in seconds) for service
     * node deposits.
     */
    function getCurrentUnbondingPeriodServiceNodeDeposit()
        external
        view
        returns (uint256);

    /**
     * @return All data related to the unbonding period (in seconds) for
     * service node deposits.
     */
    function getUnbondingPeriodServiceNodeDeposit()
        external
        view
        returns (PantosTypes.UpdatableUint256 memory);

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
     * @param blockchainId The ID of the blockchain to get the validator
     * fee factor for.
     *
     * @return The current validator fee factor for the given
     * blockchain.
     */
    function getCurrentValidatorFeeFactor(
        uint256 blockchainId
    ) external view returns (uint256);

    /**
     * @param blockchainId The ID of the blockchain to get the validator
     * fee factor for.
     *
     * @return All data related to the validator fee factor for the
     * given blockchain.
     */
    function getValidatorFeeFactor(
        uint256 blockchainId
    ) external view returns (PantosTypes.UpdatableUint256 memory);

    /**
     * @return The current time delay for updating Pantos Hub
     * parameters.
     */
    function getCurrentParameterUpdateDelay() external view returns (uint256);

    /**
     * @return All data related to the time delay for updating Pantos
     * Hub parameters.
     */
    function getParameterUpdateDelay()
        external
        view
        returns (PantosTypes.UpdatableUint256 memory);

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
