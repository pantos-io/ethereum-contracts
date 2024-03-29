// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;
pragma abicoder v2;

/* solhint-disable no-console*/

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import "../../src/contracts/PantosHub.sol";
import "../../src/contracts/PantosForwarder.sol";
import "../../src/contracts/PantosToken.sol";

import "./Constants.s.sol";
import "./PantosBaseScript.s.sol";

abstract contract PantosHubDeployer is PantosBaseScript {
    function deployPantosHub()
        public
        returns (
            ProxyAdmin,
            PantosHub, // pantosHubProxy,
            PantosHub // pantosHubLogic
        )
    {
        // This will only change if we migrate testnets
        uint256 nextTransferId = 0;
        return deployPantosHub(nextTransferId);
    }

    function deployPantosHub(
        uint256 nextTransferId
    )
        public
        returns (
            ProxyAdmin,
            PantosHub, // pantosHubProxy
            PantosHub // pantosHubLogic
        )
    {
        ProxyAdmin proxyAdmin = new ProxyAdmin();

        console2.log("ProxyAdmin deployed; address=%s", address(proxyAdmin));

        PantosHub pantosHubLogic = new PantosHub();

        console2.log(
            "PantosHub Logic deployed; paused=%s; address=%s",
            pantosHubLogic.paused(),
            address(pantosHubLogic)
        );

        Blockchain memory blockchain = determineBlockchain();
        uint256 feeFactorValidFrom = vm.unixTime() /
            1000 +
            Constants.FEE_FACTOR_VALID_FROM_OFFSET;

        bytes memory initializerData = abi.encodeCall(
            PantosHub.initialize,
            (
                uint256(blockchain.blockchainId),
                blockchain.name,
                Constants.MINIMUM_TOKEN_STAKE,
                Constants.MINIMUM_SERVICE_NODE_STAKE,
                Constants.SERVICE_NODE_STAKE_UNBONDING_PERIOD,
                blockchain.feeFactor,
                feeFactorValidFrom,
                nextTransferId
            )
        );

        // deploy proxy contract and point it to implementation
        TransparentUpgradeableProxy transparentProxy = new TransparentUpgradeableProxy(
                address(pantosHubLogic),
                address(proxyAdmin),
                initializerData
            );

        // wrap in ABI to support easier calls
        PantosHub pantosHubProxy = PantosHub(address(transparentProxy));

        console2.log(
            "PantosHub Proxy deployed; paused=%s; address=%s",
            pantosHubProxy.paused(),
            address(pantosHubProxy)
        );
        return (proxyAdmin, pantosHubProxy, pantosHubLogic);
    }

    function initializePantosHub(
        PantosHub pantosHubProxy,
        PantosForwarder pantosForwarder,
        PantosToken pantosToken,
        address primaryValidatorNodeAddress
    ) public {
        if (!pantosHubProxy.paused()) {
            pantosHubProxy.pause();
            console2.log("PantosHub: paused=%s", pantosHubProxy.paused());
        }

        // Set the forwarder, PAN token, and primary validator node
        // addresses
        address expectedForwarder = pantosHubProxy.getPantosForwarder();
        if (expectedForwarder != address(pantosForwarder)) {
            pantosHubProxy.setPantosForwarder(address(pantosForwarder));
            console2.log(
                "PantosHub.setPantosForwarder(%s)",
                address(pantosForwarder)
            );
        } else {
            console2.log(
                "PantosHub: PantosForwarder already set, "
                "skipping setPantosForwarder(%s)",
                address(pantosForwarder)
            );
        }

        address expectedPantosToken = pantosHubProxy.getPantosToken();
        if (expectedPantosToken != address(pantosToken)) {
            pantosHubProxy.setPantosToken(address(pantosToken));
            console2.log("PantosHub.setPantosToken(%s)", address(pantosToken));
        } else {
            console2.log(
                "PantosHub: PantosToken already set, "
                "skipping setPantosToken(%s)",
                address(pantosToken)
            );
        }

        address expectedPrimaryNode = pantosHubProxy.getPrimaryValidatorNode();
        if (expectedPrimaryNode != primaryValidatorNodeAddress) {
            pantosHubProxy.setPrimaryValidatorNode(
                primaryValidatorNodeAddress
            );
            console2.log(
                "PantosHub.setPrimaryValidatorNode(%s)",
                primaryValidatorNodeAddress
            );
        } else {
            console2.log(
                "PantosHub: Primary Validator already set, "
                "skipping setPrimaryValidatorNode(%s)",
                primaryValidatorNodeAddress
            );
        }

        Blockchain memory blockchain = determineBlockchain();

        uint256 feeFactorValidFrom = vm.unixTime() /
            1000 +
            Constants.FEE_FACTOR_VALID_FROM_OFFSET;

        // Register the other blockchains
        for (uint256 i; i < getBlockchainsLength(); i++) {
            Blockchain memory otherBlockchain = getBlockchainById(
                BlockchainId(i)
            );

            if (
                otherBlockchain.blockchainId != blockchain.blockchainId &&
                !otherBlockchain.skip
            ) {
                PantosTypes.BlockchainRecord
                    memory blockchainRecord = pantosHubProxy
                        .getBlockchainRecord(
                            uint256(otherBlockchain.blockchainId)
                        );
                if (!blockchainRecord.active) {
                    pantosHubProxy.registerBlockchain(
                        uint256(otherBlockchain.blockchainId),
                        otherBlockchain.name,
                        otherBlockchain.feeFactor,
                        feeFactorValidFrom
                    );
                    console2.log(
                        "PantosHub.registerBlockchain(%s) on %s",
                        otherBlockchain.name,
                        blockchain.name
                    );
                } else if (
                    keccak256(abi.encodePacked(blockchainRecord.name)) !=
                    keccak256(abi.encodePacked(otherBlockchain.name))
                ) {
                    console2.log(
                        "PantosHub: blockchain names do not match. "
                        "Unregister and register again "
                        "Old name: %s New name: %s",
                        blockchainRecord.name,
                        otherBlockchain.name
                    );
                    pantosHubProxy.unregisterBlockchain(
                        uint256(otherBlockchain.blockchainId)
                    );
                    pantosHubProxy.registerBlockchain(
                        uint256(otherBlockchain.blockchainId),
                        otherBlockchain.name,
                        otherBlockchain.feeFactor,
                        feeFactorValidFrom
                    );
                    console2.log(
                        "PantosHub.unregisterBlockchain(%s), "
                        "PantosHub.registerBlockchain(%s), ",
                        uint256(otherBlockchain.blockchainId),
                        uint256(otherBlockchain.blockchainId)
                    );
                } else {
                    console2.log(
                        "PantosHub: Blockchain %s already registered "
                        "Skipping registerBlockchain(%s)",
                        otherBlockchain.name,
                        uint256(otherBlockchain.blockchainId)
                    );
                }
            }
        }

        uint256 unbondingPeriodServiceNodeStake = pantosHubProxy
            .getUnbondingPeriodServiceNodeStake();
        if (
            unbondingPeriodServiceNodeStake !=
            Constants.SERVICE_NODE_STAKE_UNBONDING_PERIOD
        ) {
            pantosHubProxy.setUnbondingPeriodServiceNodeStake(
                Constants.SERVICE_NODE_STAKE_UNBONDING_PERIOD
            );
            console2.log(
                "PantosHub.setUnbondingPeriodServiceNodeStake(%s)",
                Constants.SERVICE_NODE_STAKE_UNBONDING_PERIOD
            );
        } else {
            console2.log(
                "PantosHub: Unbonding period of the service node "
                "stake already set, skipping "
                "setUnbondingPeriodServiceNodeStake(%s)",
                Constants.SERVICE_NODE_STAKE_UNBONDING_PERIOD
            );
        }

        // Unpause the hub contract after initialization
        pantosHubProxy.unpause();
        console2.log(
            "PantosHub initialized; paused=%s",
            pantosHubProxy.paused()
        );
    }

    function upgradePantosHub(
        ProxyAdmin proxyAdmin,
        ITransparentUpgradeableProxy transparentProxy
    ) public returns (PantosHub) {
        PantosHub newPantosHubLogic = new PantosHub();
        console2.log(
            "New PantosHub Logic deployed; paused=%s; address=%s",
            newPantosHubLogic.paused(),
            address(newPantosHubLogic)
        );

        address oldPantosHubLogicAddress = proxyAdmin.getProxyImplementation(
            transparentProxy
        );

        console2.log(
            "PantosHub old Logic address=%s",
            oldPantosHubLogicAddress
        );

        proxyAdmin.upgrade(transparentProxy, address(newPantosHubLogic));

        address newPantosHubLogicAddress = proxyAdmin.getProxyImplementation(
            transparentProxy
        );

        require(newPantosHubLogicAddress == address(newPantosHubLogic));

        // wrap in ABI to support easier calls
        PantosHub pantosHubProxy = PantosHub(address(transparentProxy));

        console2.log(
            "PantosHub Logic upgraded by proxy admin; paused=%s; address=%s",
            pantosHubProxy.paused(),
            newPantosHubLogicAddress
        );

        // this will do nothing if there is nothing new added to the storage slots
        initializePantosHub(
            pantosHubProxy,
            PantosForwarder(pantosHubProxy.getPantosForwarder()),
            PantosToken(pantosHubProxy.getPantosToken()),
            pantosHubProxy.getPrimaryValidatorNode()
        );

        return newPantosHubLogic;
    }
}
