// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;
pragma abicoder v2;

import {PantosTypes} from "../interfaces/PantosTypes.sol";
import {IPantosForwarder} from "../interfaces/IPantosForwarder.sol";
import {IPantosToken} from "../interfaces/IPantosToken.sol";
import {IPantosRegistry} from "../interfaces/IPantosRegistry.sol";

import {PantosBaseFacet} from "./PantosBaseFacet.sol";
import {PantosHubStorage} from "../PantosHubStorage.sol";

/**
 * @title Pantos Registry facet
 *
 * @notice See {IPantosRegistry}.
 */
contract PantosRegistryFacet is IPantosRegistry, PantosBaseFacet {
    /**
     * @dev See {IPantosRegistry-pause}.
     */
    function pause() external override whenNotPaused onlyOwner {
        s.paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @dev See {IPantosRegistry-unpause}.
     */
    // slither-disable-next-line timestamp
    function unpause() external override whenPaused onlyOwner {
        require(
            s.pantosForwarder != address(0),
            "PantosHub: PantosForwarder has not been set"
        );
        require(
            s.pantosToken != address(0),
            "PantosHub: PantosToken has not been set"
        );
        require(
            s.primaryValidatorNodeAddress != address(0),
            "PantosHub: primary validator node has not been set"
        );
        s.paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @dev See {IPantosRegistry-setPantosForwarder}.
     */
    // slither-disable-next-line timestamp
    function setPantosForwarder(
        address pantosForwarder
    ) external override whenPaused onlyOwner {
        require(
            pantosForwarder != address(0),
            "PantosHub: PantosForwarder must not be the zero account"
        );
        s.pantosForwarder = pantosForwarder;
        emit PantosForwarderSet(pantosForwarder);
    }

    /**
     * @dev See {IPantosRegistry-setPantosToken}.
     */
    // slither-disable-next-line timestamp
    function setPantosToken(
        address pantosToken
    ) external override whenPaused onlyOwner {
        require(
            pantosToken != address(0),
            "PantosHub: PantosToken must not be the zero account"
        );
        require(
            s.pantosToken == address(0),
            "PantosHub: PantosToken already set"
        );
        s.pantosToken = pantosToken;
        emit PantosTokenSet(pantosToken);
        registerToken(pantosToken, 0);
    }

    /**
     * @dev See {IPantosRegistry-setPrimaryValidatorNode}.
     */
    function setPrimaryValidatorNode(
        address primaryValidatorNodeAddress
    ) external override whenPaused onlyOwner {
        require(
            primaryValidatorNodeAddress != address(0),
            "PantosHub: primary validator node address must not be zero"
        );
        s.primaryValidatorNodeAddress = primaryValidatorNodeAddress;
        emit PrimaryValidatorNodeUpdated(primaryValidatorNodeAddress);
    }

    /**
     * @dev See {IPantosRegistry-registerBlockchain}.
     */
    function registerBlockchain(
        uint256 blockchainId,
        string calldata name,
        uint256 feeFactor,
        uint256 feeFactorValidFrom
    ) external override onlyOwner {
        _registerBlockchain(blockchainId, name);
        _updateFeeFactor(blockchainId, feeFactor, feeFactorValidFrom);
    }

    /**
     * @dev See {IPantosRegistry-unregisterBlockchain}.
     */
    // slither-disable-next-line timestamp
    function unregisterBlockchain(
        uint256 blockchainId
    ) external override onlyOwner {
        // Validate the input parameter
        require(
            blockchainId != s.currentBlockchainId,
            "PantosHub: blockchain ID must not be the current blockchain ID"
        );
        // Validate the stored blockchain data
        PantosTypes.BlockchainRecord storage blockchainRecord = s
            .blockchainRecords[blockchainId];
        require(
            blockchainRecord.active,
            "PantosHub: blockchain must be active"
        );
        assert(blockchainId < s.numberBlockchains);
        // Update the blockchain record
        blockchainRecord.active = false;
        // s.numberBlockchains is not updated since also a once registered but
        // now inactive blockchain counts (it keeps its blockchainId in case it
        // is registered again)
        assert(s.numberActiveBlockchains > 0);
        s.numberActiveBlockchains--;
        emit BlockchainUnregistered(blockchainId);
    }

    /**
     * @dev See {IPantosRegistry-updateBlockchainName}.
     */
    // slither-disable-next-line timestamp
    function updateBlockchainName(
        uint256 blockchainId,
        string calldata name
    ) external override whenPaused onlyOwner {
        // Validate the input parameters
        require(
            bytes(name).length > 0,
            "PantosHub: blockchain name must not be empty"
        );
        // Validate the stored blockchain data
        PantosTypes.BlockchainRecord storage blockchainRecord = s
            .blockchainRecords[blockchainId];
        require(
            blockchainRecord.active,
            "PantosHub: blockchain must be active"
        );
        assert(blockchainId < s.numberBlockchains);
        // Update the blockchain record
        blockchainRecord.name = name;
        emit BlockchainNameUpdated(blockchainId);
    }

    /**
     * @dev See {IPantosRegistry-updateFeeFactor}.
     */
    function updateFeeFactor(
        uint256 blockchainId,
        uint256 newFactor,
        uint256 validFrom
    ) external override onlyOwner {
        _updateFeeFactor(blockchainId, newFactor, validFrom);
    }

    /**
     * @dev See {IPantosRegistry-setMinimumTokenStake}.
     */
    function setMinimumTokenStake(
        uint256 minimumTokenStake
    ) public override whenPaused onlyOwner {
        s.minimumTokenStake = minimumTokenStake;
        emit MinimumTokenStakeUpdated(minimumTokenStake);
    }

    /**
     * @dev See {IPantosRegistry-setUnbondingPeriodServiceNodeStake}.
     */
    function setUnbondingPeriodServiceNodeStake(
        uint256 unbondingPeriodServiceNodeStake
    ) public override onlyOwner {
        s.unbondingPeriodServiceNodeStake = unbondingPeriodServiceNodeStake;
        emit UnbondingPeriodServiceNodeStakeUpdated(
            unbondingPeriodServiceNodeStake
        );
    }

    /**
     * @dev See {IPantosRegistry-setMinimumServiceNodeStake}.
     */
    function setMinimumServiceNodeStake(
        uint256 minimumServiceNodeStake
    ) public override whenPaused onlyOwner {
        s.minimumServiceNodeStake = minimumServiceNodeStake;
        emit MinimumServiceNodeStakeUpdated(minimumServiceNodeStake);
    }

    /**
     * @dev See {IPantosRegistry-setMinimumValidatorFeeUpdatePeriod}.
     */
    function setMinimumValidatorFeeUpdatePeriod(
        uint256 minimumValidatorFeeUpdatePeriod
    ) external override onlyOwner {
        s.minimumValidatorFeeUpdatePeriod = minimumValidatorFeeUpdatePeriod;
        emit MinimumValidatorFeeUpdatePeriodUpdated(
            minimumValidatorFeeUpdatePeriod
        );
    }

    /**
     * @dev See {IPantosRegistry-registerToken}.
     */
    // slither-disable-next-line timestamp
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
            token == s.pantosToken || stake >= s.minimumTokenStake,
            "PantosHub: stake must be >= minimum token stake"
        );
        // Validate the stored token data
        PantosTypes.TokenRecord storage tokenRecord = s.tokenRecords[token];
        require(!tokenRecord.active, "PantosHub: token must not be active");
        // Store the token record
        tokenRecord.active = true;
        tokenRecord.stake = stake;
        s.tokens.push(token);
        emit TokenRegistered(token);
        // Transfer the token stake to this contract
        if (token != s.pantosToken) {
            require(
                IPantosToken(s.pantosToken).transferFrom(
                    msg.sender,
                    address(this),
                    stake
                ),
                "PantosHub: transfer of token stake failed"
            );
        }
    }

    /**
     * @dev See {IPantosRegistry-unregisterToken}.
     */
    // slither-disable-next-line timestamp
    function unregisterToken(address token) public override ownerOrNotPaused {
        // Validate the stored token data
        PantosTypes.TokenRecord storage tokenRecord = s.tokenRecords[token];
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
            storage externalTokenRecords = s.externalTokenRecords[token];
        for (uint256 i = 0; i < s.numberBlockchains; i++) {
            if (i != s.currentBlockchainId) {
                PantosTypes.ExternalTokenRecord
                    storage externalTokenRecord = externalTokenRecords[i];
                if (externalTokenRecord.active) {
                    externalTokenRecord.active = false;
                    emit ExternalTokenUnregistered(token, i);
                }
            }
        }
        // Remove the token address
        uint numberTokens = s.tokens.length;
        for (uint i = 0; i < numberTokens; i++) {
            if (s.tokens[i] == token) {
                s.tokens[i] = s.tokens[numberTokens - 1];
                // slither-disable-next-line costly-loop
                s.tokens.pop();
                break;
            }
        }
        emit TokenUnregistered(token);
        // Refund the token stake
        if (stake > 0) {
            require(
                IPantosToken(s.pantosToken).transfer(msg.sender, stake),
                "PantosHub: refund of token stake failed"
            );
        }
    }

    /**
     * @dev See {IPantosRegistry-increaseTokenStake}.
     */
    // slither-disable-next-line timestamp
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
        PantosTypes.TokenRecord storage tokenRecord = s.tokenRecords[token];
        require(tokenRecord.active, "PantosHub: token must be active");
        uint256 newTokenStake = tokenRecord.stake + stake;
        require(
            newTokenStake >= s.minimumTokenStake,
            "PantosHub: new stake must be at least the minimum token stake"
        );
        tokenRecord.stake = newTokenStake;
        require(
            IPantosToken(s.pantosToken).transferFrom(
                msg.sender,
                address(this),
                stake
            ),
            "PantosHub: transfer of token stake failed"
        );
    }

    /**
     * @dev See {IPantosRegistry-decreaseTokenStake}.
     */
    // slither-disable-next-line timestamp
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
        PantosTypes.TokenRecord storage tokenRecord = s.tokenRecords[token];
        require(tokenRecord.active, "PantosHub: token must be active");
        uint256 newTokenStake = tokenRecord.stake - stake;
        require(
            newTokenStake >= s.minimumTokenStake,
            "PantosHub: new stake must be at least the minimum token stake"
        );
        tokenRecord.stake = newTokenStake;
        require(
            IPantosToken(s.pantosToken).transfer(msg.sender, stake),
            "PantosHub: refund of token stake failed"
        );
    }

    /**
     * @dev See {IPantosRegistry-registerExternalToken}.
     */
    // slither-disable-next-line timestamp
    function registerExternalToken(
        address token,
        uint256 blockchainId,
        string calldata externalToken
    ) external override ownerOrNotPaused {
        // Validate the input parameters
        require(
            blockchainId != s.currentBlockchainId,
            "PantosHub: blockchain must not be the current blockchain"
        );
        require(
            s.blockchainRecords[blockchainId].active,
            "PantosHub: blockchain of external token must be active"
        );
        require(
            bytes(externalToken).length > 0,
            "PantosHub: external token address must not be empty"
        );
        // Validate the stored token data
        PantosTypes.TokenRecord storage tokenRecord = s.tokenRecords[token];
        require(tokenRecord.active, "PantosHub: token must be active");
        require(
            IPantosToken(token).getOwner() == msg.sender,
            "PantosHub: caller is not the token owner"
        );
        // All tokens except for the Pantos token must stake at least the
        // minimum amount of Pantos tokens
        require(
            token == s.pantosToken || tokenRecord.stake >= s.minimumTokenStake,
            "PantosHub: token stake must be >= minimum token stake"
        );
        // Validate the stored external token data
        PantosTypes.ExternalTokenRecord storage externalTokenRecord = s
            .externalTokenRecords[token][blockchainId];
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
     * @dev See {IPantosRegistry-unregisterExternalToken}.
     */
    function unregisterExternalToken(
        address token,
        uint256 blockchainId
    ) external override ownerOrNotPaused {
        // Validate the stored token data
        PantosTypes.TokenRecord storage tokenRecord = s.tokenRecords[token];
        require(tokenRecord.active, "PantosHub: token must be active");
        require(
            IPantosToken(token).getOwner() == msg.sender,
            "PantosHub: caller is not the token owner"
        );
        // Validate the stored external token data
        PantosTypes.ExternalTokenRecord storage externalTokenRecord = s
            .externalTokenRecords[token][blockchainId];
        require(
            externalTokenRecord.active,
            "PantosHub: external token must be active"
        );
        // Update the external token record
        externalTokenRecord.active = false;
        emit ExternalTokenUnregistered(token, blockchainId);
    }

    /**
     * @dev See {IPantosRegistry-registerServiceNode}.
     */
    // slither-disable-next-line timestamp
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
        bytes32 urlHash = keccak256(bytes(url));
        require(
            !s.isServiceNodeUrlUsed[urlHash],
            "PantosHub: service node URL must be unique"
        );
        require(
            stake >= s.minimumServiceNodeStake,
            "PantosHub: stake must be >= minimum service node stake"
        );
        // Validate the stored service node data
        PantosTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[serviceNodeAddress];
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
        assert(serviceNodeRecord.lockedStake == 0);
        // Store the service node record
        serviceNodeRecord.active = true;
        serviceNodeRecord.url = url;
        serviceNodeRecord.freeStake = stake;
        serviceNodeRecord.unstakingAddress = unstakingAddress;
        s.serviceNodes.push(serviceNodeAddress);
        s.isServiceNodeUrlUsed[urlHash] = true;
        emit ServiceNodeRegistered(serviceNodeAddress);
        // Transfer the service node stake to this contract
        require(
            IPantosToken(s.pantosToken).transferFrom(
                msg.sender,
                address(this),
                stake
            ),
            "PantosHub: transfer of service node stake failed"
        );
    }

    /**
     * @dev See {IPantosRegistry-unregisterServiceNode}.
     */
    // slither-disable-next-line timestamp
    function unregisterServiceNode(
        address serviceNodeAddress
    ) external override whenNotPaused {
        // Validate the stored service node data
        PantosTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[serviceNodeAddress];
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

        assert(serviceNodeRecord.lockedStake == 0);
        // Update the service node record
        serviceNodeRecord.active = false;
        serviceNodeRecord.unregisterTime = block.timestamp;
        // Remove the service node address
        uint numberServiceNodes = s.serviceNodes.length;
        for (uint i = 0; i < numberServiceNodes; i++) {
            if (s.serviceNodes[i] == serviceNodeAddress) {
                s.serviceNodes[i] = s.serviceNodes[numberServiceNodes - 1];
                // slither-disable-next-line costly-loop
                s.serviceNodes.pop();
                break;
            }
        }
        emit ServiceNodeUnregistered(serviceNodeAddress);
    }

    /**
     * @dev See {IPantosRegistry-withdrawServiceNodeStake}.
     */
    function withdrawServiceNodeStake(
        address serviceNodeAddress
    ) external override {
        // Validate the stored service node data
        PantosTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[serviceNodeAddress];
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
                    s.unbondingPeriodServiceNodeStake,
            "PantosHub: the unbonding period has not elapsed"
        );
        uint256 stake = serviceNodeRecord.freeStake;
        // Update the service node record
        serviceNodeRecord.unregisterTime = 0;
        serviceNodeRecord.freeStake = 0;
        s.isServiceNodeUrlUsed[
            keccak256(bytes(serviceNodeRecord.url))
        ] = false;
        delete serviceNodeRecord.url;
        // Refund the service node stake
        if (stake > 0) {
            require(
                IPantosToken(s.pantosToken).transfer(
                    serviceNodeRecord.unstakingAddress,
                    stake
                ),
                "PantosHub: refund of service node stake failed"
            );
        }
    }

    /**
     * @dev See {IPantosRegistry-cancelServiceNodeUnregistration}.
     */
    function cancelServiceNodeUnregistration(
        address serviceNodeAddress
    ) external override {
        // Validate the stored service node data
        PantosTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[serviceNodeAddress];
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
        s.serviceNodes.push(serviceNodeAddress);
        emit ServiceNodeRegistered(serviceNodeAddress);
    }

    /**
     * @dev See {IPantosRegistry-increaseServiceNodeStake}.
     */
    // slither-disable-next-line timestamp
    function increaseServiceNodeStake(
        address serviceNodeAddress,
        uint256 stake
    ) external override {
        PantosTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[serviceNodeAddress];
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
            newServiceNodeStake >= s.minimumServiceNodeStake,
            "PantosHub: new stake must be at least the minimum "
            "service node stake"
        );
        serviceNodeRecord.freeStake = newServiceNodeStake;
        require(
            IPantosToken(s.pantosToken).transferFrom(
                msg.sender,
                address(this),
                stake
            ),
            "PantosHub: transfer of service node stake failed"
        );
    }

    /**
     * @dev See {IPantosRegistry-decreaseServiceNodeStake}.
     */
    // slither-disable-next-line timestamp
    function decreaseServiceNodeStake(
        address serviceNodeAddress,
        uint256 stake
    ) external override {
        PantosTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[serviceNodeAddress];
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
            newServiceNodeStake >= s.minimumServiceNodeStake,
            "PantosHub: new stake must be at least the minimum "
            "service node stake"
        );
        serviceNodeRecord.freeStake = newServiceNodeStake;
        require(
            IPantosToken(s.pantosToken).transfer(
                serviceNodeRecord.unstakingAddress,
                stake
            ),
            "PantosHub: refund of service node stake failed"
        );
    }

    /**
     * @dev See {IPantosRegistry-updateServiceNodeUrl}.
     */
    function updateServiceNodeUrl(
        string calldata url
    ) external override whenNotPaused {
        // Validate the input parameter
        require(
            bytes(url).length > 0,
            "PantosHub: service node URL must not be empty"
        );
        bytes32 urlHash = keccak256(bytes(url));
        // slither-disable-next-line timestamp
        require(
            !s.isServiceNodeUrlUsed[urlHash],
            "PantosHub: service node URL must be unique"
        );
        // Validate the stored service node data
        PantosTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[msg.sender];
        require(
            serviceNodeRecord.active,
            "PantosHub: service node must be active"
        );
        s.isServiceNodeUrlUsed[
            keccak256(bytes(serviceNodeRecord.url))
        ] = false;
        s.isServiceNodeUrlUsed[urlHash] = true;
        // Update the stored service node URL
        serviceNodeRecord.url = url;
        emit ServiceNodeUrlUpdated(msg.sender);
    }

    /**
     * @dev See {IPantosRegistry-getPantosForwarder}.
     */
    function getPantosForwarder() public view override returns (address) {
        return s.pantosForwarder;
    }

    /**
     * @dev See {IPantosRegistry-getPantosToken}.
     */
    function getPantosToken() public view override returns (address) {
        return s.pantosToken;
    }

    /**
     * @dev See {IPantosRegistry-getPrimaryValidatorNode}.
     */
    function getPrimaryValidatorNode() public view override returns (address) {
        return s.primaryValidatorNodeAddress;
    }

    /**
     * @dev See {IPantosRegistry-getNumberBlockchains}.
     */
    function getNumberBlockchains() public view override returns (uint256) {
        return s.numberBlockchains;
    }

    /**
     * @dev See {IPantosRegistry-getNumberActiveBlockchains}.
     */
    function getNumberActiveBlockchains()
        public
        view
        override
        returns (uint256)
    {
        return s.numberActiveBlockchains;
    }

    /**
     * @dev See {IPantosRegistry-getCurrentBlockchainId}.
     */
    function getCurrentBlockchainId() public view override returns (uint256) {
        return s.currentBlockchainId;
    }

    /**
     * @dev See {IPantosRegistry-getBlockchainRecord}.
     */
    function getBlockchainRecord(
        uint256 blockchainId
    ) public view override returns (PantosTypes.BlockchainRecord memory) {
        return s.blockchainRecords[blockchainId];
    }

    /**
     * @dev See {IPantosRegistry-getMinimumTokenStake}.
     */
    function getMinimumTokenStake() public view override returns (uint256) {
        return s.minimumTokenStake;
    }

    /**
     * @dev See {IPantosRegistry-getMinimumServiceNodeStake}.
     */
    function getMinimumServiceNodeStake()
        public
        view
        override
        returns (uint256)
    {
        return s.minimumServiceNodeStake;
    }

    /**
     * @dev See {IPantosRegistry-getUnbondingPeriodServiceNodeStake}.
     */
    function getUnbondingPeriodServiceNodeStake()
        public
        view
        override
        returns (uint256)
    {
        return s.unbondingPeriodServiceNodeStake;
    }

    /**
     * @dev See {IPantosRegistry-getTokens}.
     */
    function getTokens() public view override returns (address[] memory) {
        return s.tokens;
    }

    /**
     * @dev See {IPantosRegistry-getTokenRecord}.
     */
    function getTokenRecord(
        address token
    ) public view override returns (PantosTypes.TokenRecord memory) {
        return s.tokenRecords[token];
    }

    /**
     * @dev See {IPantosRegistry-getExternalTokenRecord}.
     */
    function getExternalTokenRecord(
        address token,
        uint256 blockchainId
    ) public view override returns (PantosTypes.ExternalTokenRecord memory) {
        return s.externalTokenRecords[token][blockchainId];
    }

    /**
     * @dev See {IPantosRegistry-getServiceNodes}.
     */
    function getServiceNodes()
        public
        view
        override
        returns (address[] memory)
    {
        return s.serviceNodes;
    }

    /**
     * @dev See {IPantosRegistry-getServiceNodeRecord}.
     */
    function getServiceNodeRecord(
        address serviceNode
    ) public view override returns (PantosTypes.ServiceNodeRecord memory) {
        return s.serviceNodeRecords[serviceNode];
    }

    /**
     * @dev See {IPantosRegistry-getValidatorFeeRecord}.
     */
    function getValidatorFeeRecord(
        uint256 blockchainId
    ) public view override returns (PantosTypes.ValidatorFeeRecord memory) {
        return s.validatorFeeRecords[blockchainId];
    }

    /**
     * @dev See {IPantosRegistry-getMinimumValidatorFeeUpdatePeriod}.
     */
    function getMinimumValidatorFeeUpdatePeriod()
        public
        view
        override
        returns (uint256)
    {
        return s.minimumValidatorFeeUpdatePeriod;
    }

    /**
     * @dev See {IPantosRegistry-isServiceNodeInTheUnbondingPeriod}.
     */
    function isServiceNodeInTheUnbondingPeriod(
        address serviceNodeAddress
    ) external view override returns (bool) {
        PantosTypes.ServiceNodeRecord memory serviceNodeRecord = s
            .serviceNodeRecords[serviceNodeAddress];
        // slither-disable-next-line timestamp
        return serviceNodeRecord.unregisterTime != 0;
    }

    /**
     * @dev See {IPantosRegistry-isValidValidatorNodeNonce}.
     */
    function isValidValidatorNodeNonce(
        uint256 nonce
    ) external view override returns (bool) {
        return
            IPantosForwarder(s.pantosForwarder).isValidValidatorNodeNonce(
                nonce
            );
    }

    /**
     * @dev See {IPantosRegistry-paused}.
     */
    function paused() external view returns (bool) {
        return s.paused;
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
        PantosTypes.BlockchainRecord storage blockchainRecord = s
            .blockchainRecords[blockchainId];
        require(
            !blockchainRecord.active,
            "PantosHub: blockchain already registered"
        );
        // Store the blockchain record
        blockchainRecord.active = true;
        blockchainRecord.name = name;
        if (blockchainId >= s.numberBlockchains)
            s.numberBlockchains = blockchainId + 1;
        s.numberActiveBlockchains++;
        emit BlockchainRegistered(blockchainId);
    }

    function _updateFeeFactor(
        uint256 blockchainId,
        uint256 newFactor,
        uint256 validFrom
    ) private {
        require(
            blockchainId < s.numberBlockchains,
            "PantosHub: blockchain ID not supported"
        );
        require(newFactor >= 1, "PantosHub: newFactor must be >= 1");
        // slither-disable-next-line timestamp
        require(
            validFrom >= block.timestamp + s.minimumValidatorFeeUpdatePeriod,
            "PantosHub: validFrom must be larger than "
            "(block timestamp + minimum update period)"
        );
        PantosTypes.ValidatorFeeRecord storage feeRecord = s
            .validatorFeeRecords[blockchainId];
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
}
