// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {PantosTypes} from "../interfaces/PantosTypes.sol";
import {IPantosForwarder} from "../interfaces/IPantosForwarder.sol";
import {IPantosToken} from "../interfaces/IPantosToken.sol";
import {IPantosRegistry} from "../interfaces/IPantosRegistry.sol";

import {PantosBaseFacet} from "./PantosBaseFacet.sol";
import {PantosRBAC} from "../PantosRBAC.sol";

/**
 * @title Pantos Registry facet
 *
 * @notice See {IPantosRegistry}.
 */
contract PantosRegistryFacet is IPantosRegistry, PantosBaseFacet, PantosRBAC {
    /**
     * @notice Sets the RBAC rols.
     *
     * @param _deployer The address of the deployer role
     * @param _pauser The address of the pauser role
     * @param _mediumCriticalOps The address of the medium critical ops role
     * @param _superCriticalOps The address of the super critical ops role
     */
    constructor(
        address _deployer,
        address _pauser,
        address _mediumCriticalOps,
        address _superCriticalOps
    ) PantosRBAC(_deployer, _pauser, _mediumCriticalOps, _superCriticalOps) {}

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
        registerToken(pantosToken);
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
     * @dev See {IPantosRegistry-setUnbondingPeriodServiceNodeDeposit}.
     */
    function setUnbondingPeriodServiceNodeDeposit(
        uint256 unbondingPeriodServiceNodeDeposit
    ) public override onlyOwner {
        s
            .unbondingPeriodServiceNodeDeposit = unbondingPeriodServiceNodeDeposit;
        emit UnbondingPeriodServiceNodeDepositUpdated(
            unbondingPeriodServiceNodeDeposit
        );
    }

    /**
     * @dev See {IPantosRegistry-setMinimumServiceNodeDeposit}.
     */
    function setMinimumServiceNodeDeposit(
        uint256 minimumServiceNodeDeposit
    ) public override whenPaused onlyOwner {
        s.minimumServiceNodeDeposit = minimumServiceNodeDeposit;
        emit MinimumServiceNodeDepositUpdated(minimumServiceNodeDeposit);
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
    function registerToken(address token) public override ownerOrNotPaused {
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
        // Validate the stored token data
        PantosTypes.TokenRecord storage tokenRecord = s.tokenRecords[token];
        require(!tokenRecord.active, "PantosHub: token must not be active");
        // Store the token record
        tokenRecord.active = true;
        s.tokenIndices[token] = s.tokens.length;
        s.tokens.push(token);
        emit TokenRegistered(token);
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
        uint256 tokenIndex = s.tokenIndices[token];
        uint256 maxTokenIndex = s.tokens.length - 1;
        assert(tokenIndex <= maxTokenIndex);
        assert(s.tokens[tokenIndex] == token);
        if (tokenIndex != maxTokenIndex) {
            // Replace the removed token with the last token
            address otherTokenAddress = s.tokens[maxTokenIndex];
            s.tokenIndices[otherTokenAddress] = tokenIndex;
            s.tokens[tokenIndex] = otherTokenAddress;
        }
        s.tokens.pop();
        emit TokenUnregistered(token);
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
        uint256 deposit,
        address withdrawalAddress
    ) external override whenNotPaused {
        // Validate the input parameters
        require(
            msg.sender == serviceNodeAddress ||
                msg.sender == withdrawalAddress,
            "PantosHub: caller is not the service node or the "
            "withdrawal address"
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
            deposit >= s.minimumServiceNodeDeposit,
            "PantosHub: deposit must be >= minimum service node deposit"
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
            "PantosHub: service node must withdraw its deposit or cancel "
            "the unregistration"
        );
        assert(serviceNodeRecord.deposit == 0);
        // Store the service node record
        serviceNodeRecord.active = true;
        serviceNodeRecord.url = url;
        serviceNodeRecord.deposit = deposit;
        serviceNodeRecord.withdrawalAddress = withdrawalAddress;
        s.serviceNodeIndices[serviceNodeAddress] = s.serviceNodes.length;
        s.serviceNodes.push(serviceNodeAddress);
        s.isServiceNodeUrlUsed[urlHash] = true;
        emit ServiceNodeRegistered(serviceNodeAddress);
        // Transfer the service node deposit to this contract
        require(
            IPantosToken(s.pantosToken).transferFrom(
                msg.sender,
                address(this),
                deposit
            ),
            "PantosHub: transfer of service node deposit failed"
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
                msg.sender == serviceNodeRecord.withdrawalAddress,
            "PantosHub: caller is not the service node or the "
            "withdrawal address"
        );
        require(
            serviceNodeRecord.active,
            "PantosHub: service node must be active"
        );

        // Update the service node record
        serviceNodeRecord.active = false;
        serviceNodeRecord.unregisterTime = block.timestamp;
        // Remove the service node address
        uint256 serviceNodeIndex = s.serviceNodeIndices[serviceNodeAddress];
        uint256 maxServiceNodeIndex = s.serviceNodes.length - 1;
        assert(serviceNodeIndex <= maxServiceNodeIndex);
        assert(s.serviceNodes[serviceNodeIndex] == serviceNodeAddress);
        if (serviceNodeIndex != maxServiceNodeIndex) {
            // Replace the removed service node with the last service node
            address otherServiceNodeAddress = s.serviceNodes[
                maxServiceNodeIndex
            ];
            s.serviceNodeIndices[otherServiceNodeAddress] = serviceNodeIndex;
            s.serviceNodes[serviceNodeIndex] = otherServiceNodeAddress;
        }
        s.serviceNodes.pop();
        emit ServiceNodeUnregistered(serviceNodeAddress);
    }

    /**
     * @dev See {IPantosRegistry-withdrawServiceNodeDeposit}.
     */
    function withdrawServiceNodeDeposit(
        address serviceNodeAddress
    ) external override {
        // Validate the stored service node data
        PantosTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[serviceNodeAddress];
        require(
            serviceNodeRecord.unregisterTime != 0,
            "PantosHub: service node has no deposit to withdraw"
        );
        require(
            msg.sender == serviceNodeAddress ||
                msg.sender == serviceNodeRecord.withdrawalAddress,
            "PantosHub: caller is not the service node or the "
            "withdrawal address"
        );
        // slither-disable-next-line timestamp
        require(
            block.timestamp >=
                serviceNodeRecord.unregisterTime +
                    s.unbondingPeriodServiceNodeDeposit,
            "PantosHub: the unbonding period has not elapsed"
        );
        uint256 deposit = serviceNodeRecord.deposit;
        // Update the service node record
        serviceNodeRecord.unregisterTime = 0;
        serviceNodeRecord.deposit = 0;
        s.isServiceNodeUrlUsed[
            keccak256(bytes(serviceNodeRecord.url))
        ] = false;
        delete serviceNodeRecord.url;
        // Refund the service node deposit
        if (deposit > 0) {
            require(
                IPantosToken(s.pantosToken).transfer(
                    serviceNodeRecord.withdrawalAddress,
                    deposit
                ),
                "PantosHub: refund of service node deposit failed"
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
                msg.sender == serviceNodeRecord.withdrawalAddress,
            "PantosHub: caller is not the service node or the "
            "withdrawal address"
        );
        serviceNodeRecord.active = true;
        serviceNodeRecord.unregisterTime = 0;
        s.serviceNodeIndices[serviceNodeAddress] = s.serviceNodes.length;
        s.serviceNodes.push(serviceNodeAddress);
        emit ServiceNodeRegistered(serviceNodeAddress);
    }

    /**
     * @dev See {IPantosRegistry-increaseServiceNodeDeposit}.
     */
    // slither-disable-next-line timestamp
    function increaseServiceNodeDeposit(
        address serviceNodeAddress,
        uint256 deposit
    ) external override {
        PantosTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[serviceNodeAddress];
        require(
            msg.sender == serviceNodeAddress ||
                msg.sender == serviceNodeRecord.withdrawalAddress,
            "PantosHub: caller is not the service node or the "
            "withdrawal address"
        );
        require(
            serviceNodeRecord.active,
            "PantosHub: service node must be active"
        );
        require(
            deposit > 0,
            "PantosHub: additional deposit must be greater than 0"
        );
        uint256 newServiceNodeDeposit = serviceNodeRecord.deposit + deposit;
        require(
            newServiceNodeDeposit >= s.minimumServiceNodeDeposit,
            "PantosHub: new deposit must be at least the minimum "
            "service node deposit"
        );
        serviceNodeRecord.deposit = newServiceNodeDeposit;
        require(
            IPantosToken(s.pantosToken).transferFrom(
                msg.sender,
                address(this),
                deposit
            ),
            "PantosHub: transfer of service node deposit failed"
        );
    }

    /**
     * @dev See {IPantosRegistry-decreaseServiceNodeDeposit}.
     */
    // slither-disable-next-line timestamp
    function decreaseServiceNodeDeposit(
        address serviceNodeAddress,
        uint256 deposit
    ) external override {
        PantosTypes.ServiceNodeRecord storage serviceNodeRecord = s
            .serviceNodeRecords[serviceNodeAddress];
        require(
            msg.sender == serviceNodeAddress ||
                msg.sender == serviceNodeRecord.withdrawalAddress,
            "PantosHub: caller is not the service node or the "
            "withdrawal address"
        );
        require(
            serviceNodeRecord.active,
            "PantosHub: service node must be active"
        );
        require(
            deposit > 0,
            "PantosHub: reduced deposit must be greater than 0"
        );
        uint256 newServiceNodeDeposit = serviceNodeRecord.deposit - deposit;
        require(
            newServiceNodeDeposit >= s.minimumServiceNodeDeposit,
            "PantosHub: new deposit must be at least the minimum "
            "service node deposit"
        );
        serviceNodeRecord.deposit = newServiceNodeDeposit;
        require(
            IPantosToken(s.pantosToken).transfer(
                serviceNodeRecord.withdrawalAddress,
                deposit
            ),
            "PantosHub: refund of service node deposit failed"
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
     * @dev See {IPantosRegistry-getMinimumServiceNodeDeposit}.
     */
    function getMinimumServiceNodeDeposit()
        public
        view
        override
        returns (uint256)
    {
        return s.minimumServiceNodeDeposit;
    }

    /**
     * @dev See {IPantosRegistry-getUnbondingPeriodServiceNodeDeposit}.
     */
    function getUnbondingPeriodServiceNodeDeposit()
        public
        view
        override
        returns (uint256)
    {
        return s.unbondingPeriodServiceNodeDeposit;
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
