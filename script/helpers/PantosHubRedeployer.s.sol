// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;
pragma abicoder v2;

/* solhint-disable no-console*/

import "../../src/interfaces/PantosTypes.sol";

import "../helpers/PantosHubDeployer.s.sol";

abstract contract PantosHubRedeployer is PantosHubDeployer {
    bool private _initialized;
    /// @dev Mapping of BlockchainId enum to map of tokens to external tokens addresses
    mapping(address => mapping(BlockchainId => PantosTypes.ExternalTokenRecord))
        private _ownedToExternalTokens;
    PantosToken[] private _ownedTokens;
    PantosHub private _oldPantosHubProxy;
    PantosForwarder private _pantosForwarder;
    PantosToken private _pantosToken;

    modifier onlyPantosHubRedeployerInitialized() {
        require(_initialized, "PantosHubRedeployer: not initialized");
        _;
    }

    function initializePantosHubRedeployer(
        address oldPantosHubProxyAddress
    ) public {
        _initialized = true;
        _oldPantosHubProxy = PantosHub(oldPantosHubProxyAddress);
        _pantosForwarder = PantosForwarder(
            _oldPantosHubProxy.getPantosForwarder()
        );
        _pantosToken = PantosToken(_oldPantosHubProxy.getPantosToken());
        readOwnedAndExternalTokens(_oldPantosHubProxy);
    }

    function readOwnedAndExternalTokens(PantosHub pantosHubProxy) public {
        Blockchain memory blockchain = determineBlockchain();
        address[] memory tokens = pantosHubProxy.getTokens();
        for (uint256 i = 0; i < tokens.length; i++) {
            PantosToken token = PantosToken(tokens[i]);
            if (
                token.owner() == msg.sender &&
                tokens[i] != address(_pantosToken)
            ) {
                _ownedTokens.push(token);
                for (
                    uint256 blockchainId;
                    blockchainId < getBlockchainsLength();
                    blockchainId++
                ) {
                    Blockchain memory otherBlockchain = getBlockchainById(
                        BlockchainId(blockchainId)
                    );
                    if (
                        otherBlockchain.blockchainId !=
                        blockchain.blockchainId &&
                        !otherBlockchain.skip
                    ) {
                        PantosTypes.ExternalTokenRecord
                            memory externalTokenRecord = pantosHubProxy
                                .getExternalTokenRecord(
                                    tokens[i],
                                    blockchainId
                                );
                        _ownedToExternalTokens[tokens[i]][
                            BlockchainId(blockchainId)
                        ] = externalTokenRecord;
                    }
                }
            }
        }
    }

    function migrateTokensFromOldHubToNewHub(
        PantosHub newPantosHubProxy
    ) public onlyPantosHubRedeployerInitialized {
        uint256 minimumTokenStake = newPantosHubProxy.getMinimumTokenStake();
        console2.log(
            "Migrating %d tokens from the old PantosHub to the new one",
            _ownedTokens.length
        );
        unregisterTokensFromOldHub();
        uint256 panTokensToApprove = minimumTokenStake * _ownedTokens.length;
        _pantosToken.approve(address(newPantosHubProxy), panTokensToApprove);
        console2.log("PantosToken.approve(%d)", panTokensToApprove);
        for (uint256 i = 0; i < _ownedTokens.length; i++) {
            newPantosHubProxy.registerToken(
                address(_ownedTokens[i]),
                minimumTokenStake
            );
            console2.log(
                "New PantosHub.registerToken(%s)",
                address(_ownedTokens[i])
            );
            for (
                uint256 blockchainId;
                blockchainId < getBlockchainsLength();
                blockchainId++
            ) {
                Blockchain memory blockchain = getBlockchainById(
                    BlockchainId(blockchainId)
                );
                if (!blockchain.skip) {
                    PantosTypes.ExternalTokenRecord
                        memory externalTokenRecord = _ownedToExternalTokens[
                            address(_ownedTokens[i])
                        ][BlockchainId(blockchainId)];
                    if (externalTokenRecord.active) {
                        newPantosHubProxy.registerExternalToken(
                            address(_ownedTokens[i]),
                            blockchainId,
                            externalTokenRecord.externalToken
                        );
                        console2.log(
                            "New PantosHub.registerExternalToken(%s, %s, %s)",
                            address(_ownedTokens[i]),
                            blockchain.name,
                            externalTokenRecord.externalToken
                        );
                    }
                }
            }
        }
    }

    function unregisterTokensFromOldHub()
        public
        onlyPantosHubRedeployerInitialized
    {
        for (uint256 i = 0; i < _ownedTokens.length; i++) {
            console2.log(
                "Unregistering token %s from the old PantosHub",
                address(_ownedTokens[i])
            );
            _oldPantosHubProxy.unregisterToken(address(_ownedTokens[i]));
        }
    }

    function getOldPantosHubProxy()
        public
        view
        onlyPantosHubRedeployerInitialized
        returns (PantosHub)
    {
        return _oldPantosHubProxy;
    }

    function getPantosForwarder()
        public
        view
        onlyPantosHubRedeployerInitialized
        returns (PantosForwarder)
    {
        return _pantosForwarder;
    }

    function getPantosToken()
        public
        view
        onlyPantosHubRedeployerInitialized
        returns (PantosToken)
    {
        return _pantosToken;
    }
}
