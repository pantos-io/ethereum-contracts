// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.23;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../interfaces/IPantosForwarder.sol";
import "../interfaces/IPantosHub.sol";
import "../interfaces/IPantosToken.sol";

/**
 * @title Pantos Hub
 *
 * @notice See {IPantosHub}.
 *
 * @dev See {IPantosHub}.
 */
contract PantosHub is IPantosHub, OwnableUpgradeable, PausableUpgradeable {
    address private _pantosForwarder;

    address private _pantosToken;

    address private _primaryValidatorNodeAddress;

    uint256 private _numberBlockchains;

    uint256 private _numberActiveBlockchains;

    uint256 private _currentBlockchainId;

    mapping(uint256 => PantosTypes.BlockchainRecord)
        private _blockchainRecords;

    uint256 private _minimumTokenStake;

    uint256 private _minimumServiceNodeStake;

    address[] private _tokens;

    mapping(address => PantosTypes.TokenRecord) private _tokenRecords;

    // Token address => blockchain ID => external token record
    mapping(address => mapping(uint256 => PantosTypes.ExternalTokenRecord))
        private _externalTokenRecords;

    address[] private _serviceNodes;

    mapping(address => PantosTypes.ServiceNodeRecord)
        private _serviceNodeRecords;

    uint256 private _nextTransferId;

    // Source blockchain ID => source transfer ID => already used?
    mapping(uint256 => mapping(uint256 => bool))
        private _usedSourceTransferIds;

    mapping(uint256 => PantosTypes.ValidatorFeeRecord)
        private _validatorFeeRecords;

    uint256 private _minimumValidatorFeeUpdatePeriod;

    uint256 private _unbondingPeriodServiceNodeStake;

    /**
     * @notice Initializes the Pantos Hub contract
     *
     * @param blockchainId The id of the current blockchain
     * @param blockchainName The name of the current blockchain
     * @param feeFactor The fee factor for the current blockchain
     * @param feeFactorValidFrom The timestamp from which the fee factor becomes
     * valid
     * @param nextTransferId The next transfer id to be used
     */
    function initialize(
        uint256 blockchainId,
        string memory blockchainName,
        uint256 minimumTokenStake,
        uint256 minimumServiceNodeStake,
        uint256 unbondingPeriodServiceNodeStake,
        uint256 feeFactor,
        uint256 feeFactorValidFrom,
        uint256 nextTransferId
    ) public initializer {
        __Pausable_init_unchained();
        __Ownable_init_unchained();
        // Contract is paused until it is fully initialized
        _pause();
        // Register the current blockchain
        _currentBlockchainId = blockchainId;
        _registerBlockchain(blockchainId, blockchainName);
        _updateFeeFactor(blockchainId, feeFactor, feeFactorValidFrom);
        // Set the minimum stakes
        setMinimumTokenStake(minimumTokenStake);
        setMinimumServiceNodeStake(minimumServiceNodeStake);
        // Set the service node unbonding period
        setUnbondingPeriodServiceNodeStake(unbondingPeriodServiceNodeStake);
        // Set the next transfer ID (is greater than 0 if there have already
        // been prior Pantos transfers initiated on the current blockchain)
        _nextTransferId = nextTransferId;
    }

    /**
     * @notice Modifier which makes sure that only a transaction from
     * the primary validator node is allowed.
     */
    modifier onlyPrimaryValidatorNode() {
        require(
            msg.sender == _primaryValidatorNodeAddress,
            "PantosHub: caller is not the primary validator node"
        );
        _;
    }

    /**
     * @notice Modifier which makes sure that only a transaction from the
     * Pantos Hub owner is allowed or the contract is not paused
     */
    modifier ownerOrNotPaused() {
        require(
            owner() == msg.sender || !paused(),
            "PantosHub: caller is not the owner and contract is paused"
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
            _pantosForwarder != address(0),
            "PantosHub: PantosForwarder has not been set"
        );
        require(
            _pantosToken != address(0),
            "PantosHub: PantosToken has not been set"
        );
        require(
            _primaryValidatorNodeAddress != address(0),
            "PantosHub: primary validator node has not been set"
        );
        _unpause();
    }

    /**
     * @notice Sets the Pantos Forwarder contract address
     *
     * @param pantosForwarder The address of the Pantos Forwarder contract
     *
     * @dev The function can only be called by the owner of the contract
     * and only if the contract is paused
     */
    function setPantosForwarder(
        address pantosForwarder
    ) external whenPaused onlyOwner {
        require(
            pantosForwarder != address(0),
            "PantosHub: PantosForwarder must not be the zero account"
        );
        _pantosForwarder = pantosForwarder;
        emit PantosForwarderSet(pantosForwarder);
    }

    /**
     * @notice Set the Pantos Token contract address.
     *
     * @param pantosToken The address of the Pantos Token contract.
     *
     * @dev The function can only be called by the owner of the contract
     * and only if the contract is paused.
     */
    function setPantosToken(
        address pantosToken
    ) external whenPaused onlyOwner {
        require(
            pantosToken != address(0),
            "PantosHub: PantosToken must not be the zero account"
        );
        require(
            _pantosToken == address(0),
            "PantosHub: PantosToken already set"
        );
        _pantosToken = pantosToken;
        emit PantosTokenSet(pantosToken);
        registerToken(pantosToken, 0);
    }

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
    ) external whenPaused onlyOwner {
        require(
            primaryValidatorNodeAddress != address(0),
            "PantosHub: primary validator node address must not be zero"
        );
        _primaryValidatorNodeAddress = primaryValidatorNodeAddress;
        emit PrimaryValidatorNodeUpdated(primaryValidatorNodeAddress);
    }

    /**
     * @notice Used by the owner of the Pantos Hub contract to register a new
     * blockchain
     *
     * @param blockchainId The id of the blockchain to be registered
     * @param name The name of the blockchain to be registered
     * @param feeFactor The fee factor to be used for that blockchain
     * @param feeFactorValidFrom The timestamp from which the fee factor for
     * the new blockchain becomes valid
     */
    function registerBlockchain(
        uint256 blockchainId,
        string calldata name,
        uint256 feeFactor,
        uint256 feeFactorValidFrom
    ) external onlyOwner {
        _registerBlockchain(blockchainId, name);
        _updateFeeFactor(blockchainId, feeFactor, feeFactorValidFrom);
    }

    /**
     * @notice Used by the owner of the Pantos Hub contract to unregister a
     * blockchain
     *
     * @param blockchainId The id of the blockchain to be unregistered
     */
    function unregisterBlockchain(uint256 blockchainId) external onlyOwner {
        // Validate the input parameter
        require(
            blockchainId != _currentBlockchainId,
            "PantosHub: blockchain ID must not be the current blockchain ID"
        );
        // Validate the stored blockchain data
        PantosTypes.BlockchainRecord
            storage blockchainRecord = _blockchainRecords[blockchainId];
        require(
            blockchainRecord.active,
            "PantosHub: blockchain must be active"
        );
        assert(blockchainId < _numberBlockchains);
        // Update the blockchain record
        blockchainRecord.active = false;
        // _numberBlockchains is not updated since also a once registered but
        // now inactive blockchain counts (it keeps its blockchainId in case it
        // is registered again)
        assert(_numberActiveBlockchains > 0);
        _numberActiveBlockchains--;
        emit BlockchainUnregistered(blockchainId);
    }

    /**
     * @notice Used by the owner of the Pantos Hub contract to update the name
     * of a registered blockchain
     *
     * @param blockchainId The id of the blockchain to be updated
     * @param name The new name of the blockchain
     *
     * @dev The function can only be called by the Pantos Hub owner and if the
     * contract is paused
     */
    function updateBlockchainName(
        uint256 blockchainId,
        string calldata name
    ) external whenPaused onlyOwner {
        // Validate the input parameters
        require(
            bytes(name).length > 0,
            "PantosHub: blockchain name must not be empty"
        );
        // Validate the stored blockchain data
        PantosTypes.BlockchainRecord
            storage blockchainRecord = _blockchainRecords[blockchainId];
        require(
            blockchainRecord.active,
            "PantosHub: blockchain must be active"
        );
        assert(blockchainId < _numberBlockchains);
        // Update the blockchain record
        blockchainRecord.name = name;
        emit BlockchainNameUpdated(blockchainId);
    }

    /**
     * @notice Used by the owner of the Pantos Hub contract to update the fee
     * factor of a registered blockchain
     *
     * @param blockchainId The id of the blockchain for which the fee factor is
     * updated
     * @param newFactor The new fee factor
     * @param validFrom The timestamp from which the new fee factor becomes
     * valid
     */
    function updateFeeFactor(
        uint256 blockchainId,
        uint256 newFactor,
        uint256 validFrom
    ) external onlyOwner {
        _updateFeeFactor(blockchainId, newFactor, validFrom);
    }

    /**
     * @notice Used by the owner of the Pantos Hub contract to update
     * the minimum token stake.
     *
     * @param minimumTokenStake The new minimum token stake.
     *
     * @dev The function can only be called by the Pantos Hub owner and
     * if the contract is paused.
     */
    function setMinimumTokenStake(
        uint256 minimumTokenStake
    ) public whenPaused onlyOwner {
        _minimumTokenStake = minimumTokenStake;
        emit MinimumTokenStakeUpdated(minimumTokenStake);
    }

    /**
     * @notice Used by the owner of the Pantos Hub contract to update
     * the unbonding period for the service node stake.
     *
     * @param unbondingPeriodServiceNodeStake The new unbonding period
     * for the service node stake (in seconds).
     *
     * @dev The function can only be called by the Pantos Hub owner.
     */
    function setUnbondingPeriodServiceNodeStake(
        uint256 unbondingPeriodServiceNodeStake
    ) public onlyOwner {
        _unbondingPeriodServiceNodeStake = unbondingPeriodServiceNodeStake;
        emit UnbondingPeriodServiceNodeStakeUpdated(
            unbondingPeriodServiceNodeStake
        );
    }

    /**
     * @notice Used by the owner of the Pantos Hub contract to update
     * the minimum service node stake.
     *
     * @param minimumServiceNodeStake The new minimum service node
     * stake.
     *
     * @dev The function can only be called by the Pantos Hub owner and
     * if the contract is paused.
     */
    function setMinimumServiceNodeStake(
        uint256 minimumServiceNodeStake
    ) public whenPaused onlyOwner {
        _minimumServiceNodeStake = minimumServiceNodeStake;
        emit MinimumServiceNodeStakeUpdated(minimumServiceNodeStake);
    }

    /**
     * @notice Used by the owner of the Pantos Hub contract to update the
     * minimum validator fee update period
     *
     * @param minimumValidatorFeeUpdatePeriod The new minimum validator
     * fee update period
     */
    function setMinimumValidatorFeeUpdatePeriod(
        uint256 minimumValidatorFeeUpdatePeriod
    ) external onlyOwner {
        _minimumValidatorFeeUpdatePeriod = minimumValidatorFeeUpdatePeriod;
        emit MinimumValidatorFeeUpdatePeriodUpdated(
            minimumValidatorFeeUpdatePeriod
        );
    }

    /**
     * @dev See {IPantosHub-registerToken}.
     */
    function registerToken(
        address token,
        uint256 stake
    ) public override ownerOrNotPaused {
        // Validate the input parameters
        require(
            token != address(0),
            "PantosHub: token must not be the zero account"
        );
        // Only the token owner is allowed to register the token
        require(
            IPantosToken(token).getOwner() == msg.sender,
            "PantosHub: caller is not the token owner"
        );
        // All tokens except for the Pantos token must stake at least the
        // minimum amount of Pantos tokens
        require(
            token == _pantosToken || stake >= _minimumTokenStake,
            "PantosHub: stake must be >= minimum token stake"
        );
        // Validate the stored token data
        PantosTypes.TokenRecord storage tokenRecord = _tokenRecords[token];
        require(!tokenRecord.active, "PantosHub: token must not be active");
        // Store the token record
        tokenRecord.active = true;
        tokenRecord.stake = stake;
        _tokens.push(token);
        emit TokenRegistered(token);
        // Transfer the token stake to this contract
        if (token != _pantosToken) {
            require(
                IPantosToken(_pantosToken).transferFrom(
                    msg.sender,
                    address(this),
                    stake
                ),
                "PantosHub: transfer of token stake failed"
            );
        }
    }

    /**
     * @dev See {IPantosHub-unregisterToken}.
     */
    function unregisterToken(address token) public override ownerOrNotPaused {
        // Validate the stored token data
        PantosTypes.TokenRecord storage tokenRecord = _tokenRecords[token];
        require(tokenRecord.active, "PantosHub: token must be active");
        require(
            IPantosToken(token).getOwner() == msg.sender,
            "PantosHub: caller is not the token owner"
        );
        // Update the token record
        tokenRecord.active = false;
        uint256 stake = tokenRecord.stake;
        tokenRecord.stake = 0;
        // Inactivate the associated external tokens
        mapping(uint256 => PantosTypes.ExternalTokenRecord)
            storage externalTokenRecords = _externalTokenRecords[token];
        for (uint256 i = 0; i < _numberBlockchains; i++) {
            if (i != _currentBlockchainId) {
                PantosTypes.ExternalTokenRecord
                    storage externalTokenRecord = externalTokenRecords[i];
                if (externalTokenRecord.active) {
                    externalTokenRecord.active = false;
                    emit ExternalTokenUnregistered(token, i);
                }
            }
        }
        // Remove the token address
        uint numberTokens = _tokens.length;
        for (uint i = 0; i < numberTokens; i++) {
            if (_tokens[i] == token) {
                _tokens[i] = _tokens[numberTokens - 1];
                // slither-disable-next-line costly-loop
                _tokens.pop();
                break;
            }
        }
        emit TokenUnregistered(token);
        // Refund the token stake
        if (stake > 0) {
            require(
                IPantosToken(_pantosToken).transfer(msg.sender, stake),
                "PantosHub: refund of token stake failed"
            );
        }
    }

    /**
     * @dev See {IPantosHub-registerExternalToken}.
     */
    function registerExternalToken(
        address token,
        uint256 blockchainId,
        string calldata externalToken
    ) external override ownerOrNotPaused {
        // Validate the input parameters
        require(
            blockchainId != _currentBlockchainId,
            "PantosHub: blockchain must not be the current blockchain"
        );
        require(
            _blockchainRecords[blockchainId].active,
            "PantosHub: blockchain of external token must be active"
        );
        require(
            bytes(externalToken).length > 0,
            "PantosHub: external token address must not be empty"
        );
        // Validate the stored token data
        PantosTypes.TokenRecord storage tokenRecord = _tokenRecords[token];
        require(tokenRecord.active, "PantosHub: token must be active");
        require(
            IPantosToken(token).getOwner() == msg.sender,
            "PantosHub: caller is not the token owner"
        );
        // All tokens except for the Pantos token must stake at least the
        // minimum amount of Pantos tokens
        require(
            token == _pantosToken || tokenRecord.stake >= _minimumTokenStake,
            "PantosHub: token stake must be >= minimum token stake"
        );
        // Validate the stored external token data
        PantosTypes.ExternalTokenRecord
            storage externalTokenRecord = _externalTokenRecords[token][
                blockchainId
            ];
        require(
            !externalTokenRecord.active,
            "PantosHub: external token must not be active"
        );
        // Store the external token record
        externalTokenRecord.active = true;
        externalTokenRecord.externalToken = externalToken;
        emit ExternalTokenRegistered(token, blockchainId);
    }

    /**
     * @dev See {IPantosHub-unregisterExternalToken}.
     */
    function unregisterExternalToken(
        address token,
        uint256 blockchainId
    ) external override ownerOrNotPaused {
        // Validate the stored token data
        PantosTypes.TokenRecord storage tokenRecord = _tokenRecords[token];
        require(tokenRecord.active, "PantosHub: token must be active");
        require(
            IPantosToken(token).getOwner() == msg.sender,
            "PantosHub: caller is not the token owner"
        );
        // Validate the stored external token data
        PantosTypes.ExternalTokenRecord
            storage externalTokenRecord = _externalTokenRecords[token][
                blockchainId
            ];
        require(
            externalTokenRecord.active,
            "PantosHub: external token must be active"
        );
        // Update the external token record
        externalTokenRecord.active = false;
        emit ExternalTokenUnregistered(token, blockchainId);
    }

    /**
     * @dev See {IPantosHub-increaseTokenStake}.
     */
    function increaseTokenStake(
        address token,
        uint256 stake
    ) external override {
        require(
            IPantosToken(token).getOwner() == msg.sender,
            "PantosHub: caller is not the token owner"
        );
        require(
            stake > 0,
            "PantosHub: additional stake must be greater than 0"
        );
        // Validate the stored token data
        PantosTypes.TokenRecord storage tokenRecord = _tokenRecords[token];
        require(tokenRecord.active, "PantosHub: token must be active");
        uint256 newTokenStake = tokenRecord.stake + stake;
        require(
            newTokenStake >= _minimumTokenStake,
            "PantosHub: new stake must be at least the minimum token stake"
        );
        tokenRecord.stake = newTokenStake;
        require(
            IPantosToken(_pantosToken).transferFrom(
                msg.sender,
                address(this),
                stake
            ),
            "PantosHub: transfer of token stake failed"
        );
    }

    /**
     * @dev See {IPantosHub-decreaseTokenStake}.
     */
    function decreaseTokenStake(
        address token,
        uint256 stake
    ) external override {
        require(
            IPantosToken(token).getOwner() == msg.sender,
            "PantosHub: caller is not the token owner"
        );
        require(stake > 0, "PantosHub: reduced stake must be greater than 0");
        // Validate the stored token data
        PantosTypes.TokenRecord storage tokenRecord = _tokenRecords[token];
        require(tokenRecord.active, "PantosHub: token must be active");
        uint256 newTokenStake = tokenRecord.stake - stake;
        require(
            newTokenStake >= _minimumTokenStake,
            "PantosHub: new stake must be at least the minimum token stake"
        );
        tokenRecord.stake = newTokenStake;
        require(
            IPantosToken(_pantosToken).transfer(msg.sender, stake),
            "PantosHub: refund of token stake failed"
        );
    }

    /**
     * @dev See {IPantosHub-registerServiceNode}.
     */
    function registerServiceNode(
        address serviceNodeAddress,
        string calldata url,
        uint256 stake,
        address unstakingAddress
    ) external override whenNotPaused {
        // Validate the input parameters
        require(
            msg.sender == serviceNodeAddress || msg.sender == unstakingAddress,
            "PantosHub: caller is not the service node or the "
            "unstaking address"
        );
        require(
            bytes(url).length > 0,
            "PantosHub: service node URL must not be empty"
        );
        require(
            _isUniqueServiceNodeUrl(url),
            "PantosHub: service node URL must be unique"
        );
        require(
            stake >= _minimumServiceNodeStake,
            "PantosHub: stake must be >= minimum service node stake"
        );
        // Validate the stored service node data
        PantosTypes.ServiceNodeRecord
            storage serviceNodeRecord = _serviceNodeRecords[
                serviceNodeAddress
            ];
        require(
            !serviceNodeRecord.active,
            "PantosHub: service node already registered"
        );
        require(
            serviceNodeRecord.unregisterTime == 0,
            "PantosHub: service node must withdraw its stake or cancel "
            "the unregistration"
        );
        assert(serviceNodeRecord.freeStake == 0);
        // TODO Uncomment after extraction to facet:
        // assert(serviceNodeRecord.lockedStake == 0);
        // Store the service node record
        serviceNodeRecord.active = true;
        serviceNodeRecord.url = url;
        serviceNodeRecord.freeStake = stake;
        serviceNodeRecord.unstakingAddress = unstakingAddress;
        _serviceNodes.push(serviceNodeAddress);
        emit ServiceNodeRegistered(serviceNodeAddress);
        // Transfer the service node stake to this contract
        require(
            IPantosToken(_pantosToken).transferFrom(
                msg.sender,
                address(this),
                stake
            ),
            "PantosHub: transfer of service node stake failed"
        );
    }

    /**
     * @dev See {IPantosHub-unregisterServiceNode}.
     */
    // slither-disable-next-line timestamp
    function unregisterServiceNode(
        address serviceNodeAddress
    ) external override whenNotPaused {
        // Validate the stored service node data
        PantosTypes.ServiceNodeRecord
            storage serviceNodeRecord = _serviceNodeRecords[
                serviceNodeAddress
            ];
        require(
            msg.sender == serviceNodeAddress ||
                msg.sender == serviceNodeRecord.unstakingAddress,
            "PantosHub: caller is not the service node or the "
            "unstaking address"
        );
        require(
            serviceNodeRecord.active,
            "PantosHub: service node must be active"
        );
        // TODO Uncomment after extraction to facet:
        // assert(serviceNodeRecord.lockedStake == 0);
        // Update the service node record
        serviceNodeRecord.active = false;
        serviceNodeRecord.unregisterTime = block.timestamp;
        // Remove the service node address
        uint numberServiceNodes = _serviceNodes.length;
        for (uint i = 0; i < numberServiceNodes; i++) {
            if (_serviceNodes[i] == serviceNodeAddress) {
                _serviceNodes[i] = _serviceNodes[numberServiceNodes - 1];
                // slither-disable-next-line costly-loop
                _serviceNodes.pop();
                break;
            }
        }
        emit ServiceNodeUnregistered(serviceNodeAddress);
    }

    /**
     * @dev See {IPantosHub-withdrawServiceNodeStake}.
     */
    function withdrawServiceNodeStake(
        address serviceNodeAddress
    ) external override {
        // Validate the stored service node data
        PantosTypes.ServiceNodeRecord
            storage serviceNodeRecord = _serviceNodeRecords[
                serviceNodeAddress
            ];
        require(
            serviceNodeRecord.unregisterTime != 0,
            "PantosHub: service node has no stake to withdraw"
        );
        require(
            msg.sender == serviceNodeAddress ||
                msg.sender == serviceNodeRecord.unstakingAddress,
            "PantosHub: caller is not the service node or the "
            "unstaking address"
        );
        // slither-disable-next-line timestamp
        require(
            block.timestamp >=
                serviceNodeRecord.unregisterTime +
                    _unbondingPeriodServiceNodeStake,
            "PantosHub: the unbonding period has not elapsed"
        );
        uint256 stake = serviceNodeRecord.freeStake;
        // Update the service node record
        serviceNodeRecord.unregisterTime = 0;
        serviceNodeRecord.freeStake = 0;
        // Refund the service node stake
        if (stake > 0) {
            require(
                IPantosToken(_pantosToken).transfer(
                    serviceNodeRecord.unstakingAddress,
                    stake
                ),
                "PantosHub: refund of service node stake failed"
            );
        }
    }

    /**
     * @dev See {IPantosHub-cancelServiceNodeUnregistration}.
     */
    function cancelServiceNodeUnregistration(
        address serviceNodeAddress
    ) external override {
        // Validate the stored service node data
        PantosTypes.ServiceNodeRecord
            storage serviceNodeRecord = _serviceNodeRecords[
                serviceNodeAddress
            ];
        require(
            serviceNodeRecord.unregisterTime != 0,
            "PantosHub: service node is not in the unbonding period"
        );
        require(
            msg.sender == serviceNodeAddress ||
                msg.sender == serviceNodeRecord.unstakingAddress,
            "PantosHub: caller is not the service node or the "
            "unstaking address"
        );
        serviceNodeRecord.active = true;
        serviceNodeRecord.unregisterTime = 0;
        _serviceNodes.push(serviceNodeAddress);
        emit ServiceNodeRegistered(serviceNodeAddress);
    }

    /**
     * @dev See {IPantosHub-increaseServiceNodeStake}.
     */
    function increaseServiceNodeStake(
        address serviceNodeAddress,
        uint256 stake
    ) external override {
        PantosTypes.ServiceNodeRecord
            storage serviceNodeRecord = _serviceNodeRecords[
                serviceNodeAddress
            ];
        require(
            msg.sender == serviceNodeAddress ||
                msg.sender == serviceNodeRecord.unstakingAddress,
            "PantosHub: caller is not the service node or the "
            "unstaking address"
        );
        require(
            serviceNodeRecord.active,
            "PantosHub: service node must be active"
        );
        require(
            stake > 0,
            "PantosHub: additional stake must be greater than 0"
        );
        uint256 newServiceNodeStake = serviceNodeRecord.freeStake + stake;
        require(
            newServiceNodeStake >= _minimumServiceNodeStake,
            "PantosHub: new stake must be at least the minimum "
            "service node stake"
        );
        serviceNodeRecord.freeStake = newServiceNodeStake;
        require(
            IPantosToken(_pantosToken).transferFrom(
                msg.sender,
                address(this),
                stake
            ),
            "PantosHub: transfer of service node stake failed"
        );
    }

    /**
     * @dev See {IPantosHub-decreaseServiceNodeStake}.
     */
    function decreaseServiceNodeStake(
        address serviceNodeAddress,
        uint256 stake
    ) external override {
        PantosTypes.ServiceNodeRecord
            storage serviceNodeRecord = _serviceNodeRecords[
                serviceNodeAddress
            ];
        require(
            msg.sender == serviceNodeAddress ||
                msg.sender == serviceNodeRecord.unstakingAddress,
            "PantosHub: caller is not the service node or the "
            "unstaking address"
        );
        require(
            serviceNodeRecord.active,
            "PantosHub: service node must be active"
        );
        require(stake > 0, "PantosHub: reduced stake must be greater than 0");
        uint256 newServiceNodeStake = serviceNodeRecord.freeStake - stake;
        require(
            newServiceNodeStake >= _minimumServiceNodeStake,
            "PantosHub: new stake must be at least the minimum "
            "service node stake"
        );
        serviceNodeRecord.freeStake = newServiceNodeStake;
        require(
            IPantosToken(_pantosToken).transfer(
                serviceNodeRecord.unstakingAddress,
                stake
            ),
            "PantosHub: refund of service node stake failed"
        );
    }

    /**
     * @dev See {IPantosHub-updateServiceNodeUrl}.
     */
    function updateServiceNodeUrl(
        string calldata url
    ) external override whenNotPaused {
        // Validate the input parameter
        require(
            bytes(url).length > 0,
            "PantosHub: service node URL must not be empty"
        );
        require(
            _isUniqueServiceNodeUrl(url),
            "PantosHub: service node URL must be unique"
        );
        // Validate the stored service node data
        PantosTypes.ServiceNodeRecord
            storage serviceNodeRecord = _serviceNodeRecords[msg.sender];
        require(
            serviceNodeRecord.active,
            "PantosHub: service node must be active"
        );
        // Update the stored service node URL
        serviceNodeRecord.url = url;
        emit ServiceNodeUrlUpdated(msg.sender);
    }

    /**
     * @dev See {IPantosHub-transfer}.
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
        // Service node's stake is currently not locked since there would be
        // no benefit for transfers as they are handled now
        // Assign a new transfer ID
        uint256 transferId = _nextTransferId++;
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
        IPantosForwarder(_pantosForwarder).verifyAndForwardTransfer(
            request,
            signature
        );
        return transferId;
    }

    /**
     * @dev See {IPantosHub-transferFrom}.
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
        // Service node's stake is currently not locked since there would be
        // no benefit for transfers as they are handled now
        // Assign a new transfer ID
        uint256 sourceTransferId = _nextTransferId++;
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
            PantosTypes.ValidatorFeeRecord
                memory sourceFeeRecord = _validatorFeeRecords[
                    _currentBlockchainId
                ];
            PantosTypes.ValidatorFeeRecord
                memory destinationFeeRecord = _validatorFeeRecords[
                    request.destinationBlockchainId
                ];
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
            IPantosForwarder(_pantosForwarder).verifyAndForwardTransferFrom(
                sourceBlockchainFactor,
                destinationBlockchainFactor,
                request,
                signature
            );
        }
        return sourceTransferId;
    }

    /**
     * @dev See {IPantosHub-transferTo}.
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
        _usedSourceTransferIds[request.sourceBlockchainId][
            request.sourceTransferId
        ] = true;
        // Assign a new transfer ID
        uint256 destinationTransferId = _nextTransferId++;
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
        IPantosForwarder(_pantosForwarder).verifyAndForwardTransferTo(
            request,
            signerAddresses,
            signatures
        );
        return destinationTransferId;
    }

    /**
     * @dev See {IPantosHub-isServiceNodeInTheUnbondingPeriod}.
     */
    function isServiceNodeInTheUnbondingPeriod(
        address serviceNodeAddress
    ) external view override returns (bool) {
        PantosTypes.ServiceNodeRecord
            memory serviceNodeRecord = _serviceNodeRecords[serviceNodeAddress];
        // slither-disable-next-line timestamp
        return serviceNodeRecord.unregisterTime != 0;
    }

    /**
     * @dev See {IPantosHub-isValidValidatorNodeNonce}.
     */
    function isValidValidatorNodeNonce(
        uint256 nonce
    ) external view override returns (bool) {
        return
            IPantosForwarder(_pantosForwarder).isValidValidatorNodeNonce(
                nonce
            );
    }

    /**
     * @dev See {IPantosHub-isValidSenderNonce}.
     */
    function isValidSenderNonce(
        address sender,
        uint256 nonce
    ) external view override returns (bool) {
        return
            IPantosForwarder(_pantosForwarder).isValidSenderNonce(
                sender,
                nonce
            );
    }

    /**
     * @dev See {IPantosHub-verifyTransfer}.
     */
    function verifyTransfer(
        PantosTypes.TransferRequest calldata request,
        bytes memory signature
    ) external view override {
        // Verify the token and service node
        _verifyTransfer(request);
        // Verify the remaining transfer request (including the signature)
        IPantosForwarder(_pantosForwarder).verifyTransfer(request, signature);
        // Verify the sender's balance
        _verifyTransferBalance(
            request.sender,
            request.token,
            request.amount,
            request.fee
        );
    }

    /**
     * @dev See {IPantosHub-verifyTransferFrom}.
     */
    function verifyTransferFrom(
        PantosTypes.TransferFromRequest calldata request,
        bytes memory signature
    ) external view override {
        // Verify the destination blockchain, token, and service node
        _verifyTransferFrom(request);
        // Verify the remaining transfer request (including the signature)
        IPantosForwarder(_pantosForwarder).verifyTransferFrom(
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
     * @dev See {IPantosHub-verifyTransferTo}.
     */
    function verifyTransferTo(
        PantosTypes.TransferToRequest memory request,
        address[] memory signerAddresses,
        bytes[] memory signatures
    ) external view override {
        // Verify the source blockchain and token
        _verifyTransferTo(request);
        // Verify the remaining transfer request (including the signatures)
        IPantosForwarder(_pantosForwarder).verifyTransferTo(
            request,
            signerAddresses,
            signatures
        );
    }

    /**
     * @dev See {IPantosHub-getPantosForwarder}.
     */
    function getPantosForwarder() public view override returns (address) {
        return _pantosForwarder;
    }

    /**
     * @dev See {IPantosHub-getPantosToken}.
     */
    function getPantosToken() public view override returns (address) {
        return _pantosToken;
    }

    /**
     * @dev See {IPantosHub-getPrimaryValidatorNode}.
     */
    function getPrimaryValidatorNode() public view override returns (address) {
        return _primaryValidatorNodeAddress;
    }

    /**
     * @dev See {IPantosHub-getNumberBlockchains}.
     */
    function getNumberBlockchains() public view override returns (uint256) {
        return _numberBlockchains;
    }

    /**
     * @dev See {IPantosHub-getNumberActiveBlockchains}.
     */
    function getNumberActiveBlockchains()
        public
        view
        override
        returns (uint256)
    {
        return _numberActiveBlockchains;
    }

    /**
     * @dev See {IPantosHub-getCurrentBlockchainId}.
     */
    function getCurrentBlockchainId() public view override returns (uint256) {
        return _currentBlockchainId;
    }

    /**
     * @dev See {IPantosHub-getBlockchainRecord}.
     */
    function getBlockchainRecord(
        uint256 blockchainId
    ) public view override returns (PantosTypes.BlockchainRecord memory) {
        return _blockchainRecords[blockchainId];
    }

    /**
     * @dev See {IPantosHub-getMinimumTokenStake}.
     */
    function getMinimumTokenStake() public view override returns (uint256) {
        return _minimumTokenStake;
    }

    /**
     * @dev See {IPantosHub-getMinimumServiceNodeStake}.
     */
    function getMinimumServiceNodeStake()
        public
        view
        override
        returns (uint256)
    {
        return _minimumServiceNodeStake;
    }

    /**
     * @dev See {IPantosHub-getUnbondingPeriodServiceNodeStake}.
     */
    function getUnbondingPeriodServiceNodeStake()
        public
        view
        override
        returns (uint256)
    {
        return _unbondingPeriodServiceNodeStake;
    }

    /**
     * @dev See {IPantosHub-getTokens}.
     */
    function getTokens() public view override returns (address[] memory) {
        return _tokens;
    }

    /**
     * @dev See {IPantosHub-getTokenRecord}.
     */
    function getTokenRecord(
        address token
    ) public view override returns (PantosTypes.TokenRecord memory) {
        return _tokenRecords[token];
    }

    /**
     * @dev See {IPantosHub-getExternalTokenRecord}.
     */
    function getExternalTokenRecord(
        address token,
        uint256 blockchainId
    ) public view override returns (PantosTypes.ExternalTokenRecord memory) {
        return _externalTokenRecords[token][blockchainId];
    }

    /**
     * @dev See {IPantosHub-getServiceNodes}.
     */
    function getServiceNodes()
        public
        view
        override
        returns (address[] memory)
    {
        return _serviceNodes;
    }

    /**
     * @dev See {IPantosHub-getServiceNodeRecord}.
     */
    function getServiceNodeRecord(
        address serviceNode
    ) public view override returns (PantosTypes.ServiceNodeRecord memory) {
        return _serviceNodeRecords[serviceNode];
    }

    function getNextTransferId() public view returns (uint256) {
        return _nextTransferId;
    }

    /**
     * @dev See {IPantosHub-getValidatorFeeRecord}.
     */
    function getValidatorFeeRecord(
        uint256 blockchainId
    ) public view override returns (PantosTypes.ValidatorFeeRecord memory) {
        return _validatorFeeRecords[blockchainId];
    }

    /**
     * @dev See {IPantosHub-getMinimumValidatorFeeUpdatePeriod}.
     */
    function getMinimumValidatorFeeUpdatePeriod()
        public
        view
        override
        returns (uint256)
    {
        return _minimumValidatorFeeUpdatePeriod;
    }

    function _registerBlockchain(
        uint256 blockchainId,
        string memory name
    ) private onlyOwner {
        // Validate the input parameters
        require(
            bytes(name).length > 0,
            "PantosHub: blockchain name must not be empty"
        );
        // Validate the stored blockchain data
        PantosTypes.BlockchainRecord
            storage blockchainRecord = _blockchainRecords[blockchainId];
        require(
            !blockchainRecord.active,
            "PantosHub: blockchain already registered"
        );
        // Store the blockchain record
        blockchainRecord.active = true;
        blockchainRecord.name = name;
        if (blockchainId >= _numberBlockchains)
            _numberBlockchains = blockchainId + 1;
        _numberActiveBlockchains++;
        emit BlockchainRegistered(blockchainId);
    }

    function _updateFeeFactor(
        uint256 blockchainId,
        uint256 newFactor,
        uint256 validFrom
    ) private {
        require(
            blockchainId < _numberBlockchains,
            "PantosHub: blockchain ID not supported"
        );
        require(newFactor >= 1, "PantosHub: newFactor must be >= 1");
        // slither-disable-next-line timestamp
        require(
            validFrom >= block.timestamp + _minimumValidatorFeeUpdatePeriod,
            "PantosHub: validFrom must be larger than "
            "(block timestamp + minimum update period)"
        );
        PantosTypes.ValidatorFeeRecord
            storage feeRecord = _validatorFeeRecords[blockchainId];
        // slither-disable-next-line timestamp
        if (block.timestamp >= feeRecord.validFrom) {
            feeRecord.oldFactor = feeRecord.newFactor;
        }
        feeRecord.newFactor = newFactor;
        feeRecord.validFrom = validFrom;
        emit ValidatorFeeUpdated(
            blockchainId,
            feeRecord.oldFactor,
            newFactor,
            validFrom
        );
    }

    function _isUniqueServiceNodeUrl(
        string calldata url
    ) private view returns (bool) {
        // Hash of the input URL for comparison with the stored URLs
        bytes32 urlHash = keccak256(bytes(url));
        // Compare the URLs of all registered service nodes
        uint numberServiceNodes = _serviceNodes.length;
        for (uint i = 0; i < numberServiceNodes; i++) {
            PantosTypes.ServiceNodeRecord
                storage serviceNodeRecord = _serviceNodeRecords[
                    _serviceNodes[i]
                ];
            // Both active and inactive service nodes are considered here
            bytes32 storedUrlHash = keccak256(bytes(serviceNodeRecord.url));
            if (storedUrlHash == urlHash) return false;
        }
        return true;
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
            request.destinationBlockchainId != _currentBlockchainId,
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
        if (request.sourceBlockchainId != _currentBlockchainId) {
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
        PantosTypes.BlockchainRecord
            storage blockchainRecord = _blockchainRecords[blockchainId];
        require(
            blockchainRecord.active,
            "PantosHub: blockchain must be active"
        );
    }

    function _verifyTransferToken(address token) private view {
        PantosTypes.TokenRecord storage tokenRecord = _tokenRecords[token];
        require(tokenRecord.active, "PantosHub: token must be registered");
        require(
            IPantosToken(token).getPantosForwarder() == _pantosForwarder,
            "PantosHub: Forwarder of Hub and transferred token must match"
        );
    }

    function _verifyTransferExternalToken(
        address token,
        uint256 blockchainId,
        string memory externalToken
    ) private view {
        // External token must be active
        PantosTypes.ExternalTokenRecord
            storage externalTokenRecord = _externalTokenRecords[token][
                blockchainId
            ];
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
        PantosTypes.ServiceNodeRecord
            storage serviceNodeRecord = _serviceNodeRecords[serviceNode];
        require(
            serviceNodeRecord.active,
            "PantosHub: service node must be registered"
        );
        // Service node must have enough free stake
        require(
            serviceNodeRecord.freeStake >= _minimumServiceNodeStake,
            "PantosHub: service node must have enough free stake"
        );
    }

    function _verifyTransferBalance(
        address sender,
        address token,
        uint256 amount,
        uint256 fee
    ) private view {
        if (token == _pantosToken) {
            require(
                (amount + fee) <= IERC20(_pantosToken).balanceOf(sender),
                "PantosHub: insufficient balance of sender"
            );
        } else {
            require(
                amount <= IERC20(token).balanceOf(sender),
                "PantosHub: insufficient balance of sender"
            );
            require(
                fee <= IERC20(_pantosToken).balanceOf(sender),
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
            !_usedSourceTransferIds[sourceBlockchainId][sourceTransferId],
            "PantosHub: source transfer ID already used"
        );
    }
}
