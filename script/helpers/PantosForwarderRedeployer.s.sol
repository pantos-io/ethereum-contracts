// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {PantosToken} from "../../src/PantosToken.sol";
import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {AccessController} from "../../src/access/AccessController.sol";

import {PantosBaseAddresses} from "../helpers/PantosBaseAddresses.s.sol";
import {PantosForwarderDeployer} from "../helpers/PantosForwarderDeployer.s.sol";

interface IOldPantosForwarder {
    function getPantosValidator() external returns (address);
}

abstract contract PantosForwarderRedeployer is
    PantosForwarderDeployer,
    PantosBaseAddresses
{
    bool private _initialized;
    IPantosHub private _pantosHubProxy;
    PantosToken private _pantosToken;
    AccessController private _accessController;

    modifier onlyPantosForwarderRedeployerInitialized() {
        require(_initialized, "PantosHubRedeployer: not initialized");
        _;
    }

    function initializePantosForwarderRedeployer(
        address pantosHubProxyAddress
    ) public {
        _pantosHubProxy = IPantosHub(pantosHubProxyAddress);
        _pantosToken = PantosToken(_pantosHubProxy.getPantosToken());
        readContractAddresses(determineBlockchain());
        _accessController = AccessController(
            getContractAddress(determineBlockchain(), "access_controller")
        );
        _initialized = true;
    }

    function tryGetValidatorNodes(
        PantosForwarder oldForwarder
    ) public returns (address[] memory) {
        address[] memory validatorNodeAddresses;

        // Trying to call newly added function.
        // If it is not available, catch block will try older version
        try oldForwarder.getValidatorNodes() returns (
            address[] memory result
        ) {
            validatorNodeAddresses = result;
        } catch {
            // delete catch block if all envs updated with new contract
            console.log(
                "Failed to find new method getValidatorNodes(); "
                "will try old method getPantosValidator()"
            );
            validatorNodeAddresses = new address[](1);
            validatorNodeAddresses[0] = IOldPantosForwarder(
                address(oldForwarder)
            ).getPantosValidator();
        }
        return validatorNodeAddresses;
    }

    function initializePantosForwarder(
        PantosForwarder newForwarder
    ) public onlyPantosForwarderRedeployerInitialized {
        PantosForwarder oldForwarder = PantosForwarder(
            _pantosHubProxy.getPantosForwarder()
        );
        address[] memory validatorNodeAddresses = tryGetValidatorNodes(
            oldForwarder
        );
        initializePantosForwarder(
            newForwarder,
            _pantosHubProxy,
            _pantosToken,
            validatorNodeAddresses
        );
    }

    function migrateForwarderAtHub(
        PantosForwarder pantosForwarder
    ) public onlyPantosForwarderRedeployerInitialized {
        require(
            _pantosHubProxy.paused(),
            "PantosHub should be paused before migrateForwarderAtHub"
        );
        _pantosHubProxy.setPantosForwarder(address(pantosForwarder));
        _pantosHubProxy.unpause();
        console.log(
            "PantosHub setPantosForwarder(%s); paused=%s",
            address(pantosForwarder),
            _pantosHubProxy.paused()
        );
    }

    function migrateForwarderAtTokens(
        PantosForwarder pantosForwarder,
        address pauser,
        address superCriticalOps
    ) public onlyPantosForwarderRedeployerInitialized {
        Blockchain memory thisBlockchain = determineBlockchain();

        string[] memory tokenSymbols = getTokenSymbols();
        for (uint256 i = 0; i < tokenSymbols.length; i++) {
            string memory tokenSymbol = tokenSymbols[i];
            address tokenAddress = getContractAddress(
                thisBlockchain,
                tokenSymbol
            );
            PantosToken token = PantosToken(tokenAddress);

            vm.broadcast(pauser);
            token.pause();

            vm.startBroadcast(superCriticalOps);
            token.setPantosForwarder(address(pantosForwarder));
            token.unpause();
            vm.stopBroadcast();

            console.log(
                "%s setPantosForwarder(%s); paused=%s",
                token.name(),
                address(pantosForwarder),
                token.paused()
            );
        }
    }
}
