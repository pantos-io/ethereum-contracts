// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;
pragma abicoder v2;

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {PantosToken} from "../../src/PantosToken.sol";
import {PantosForwarder} from "../../src/PantosForwarder.sol";

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
        _initialized = true;
    }

    function deployAndInitializePantosForwarder()
        public
        returns (PantosForwarder)
    {
        PantosForwarder pantosForwarder = deployPantosForwarder();
        address[] memory validatorNodeAddresses;

        // Trying to call newly added function.
        // If it is not available, catch block will try older version
        try
            PantosForwarder(_pantosHubProxy.getPantosForwarder())
                .getValidatorNodes()
        returns (address[] memory result) {
            validatorNodeAddresses = result;
        } catch {
            // delete catch block if all envs updated with new contract
            console2.log(
                "Failed to find new method getValidatorNodes(); "
                "will try old method getPantosValidator()"
            );
            validatorNodeAddresses = new address[](1);
            validatorNodeAddresses[0] = IOldPantosForwarder(
                _pantosHubProxy.getPantosForwarder()
            ).getPantosValidator();
        }
        initializePantosForwarder(
            pantosForwarder,
            _pantosHubProxy,
            _pantosToken,
            validatorNodeAddresses
        );
        return pantosForwarder;
    }

    function migrateForwarderAtHub(
        PantosForwarder pantosForwarder
    ) public onlyPantosForwarderRedeployerInitialized {
        _pantosHubProxy.pause();
        _pantosHubProxy.setPantosForwarder(address(pantosForwarder));
        _pantosHubProxy.unpause();
        console2.log(
            "PantosHub setPantosForwarder(%s); paused=%s",
            address(pantosForwarder),
            _pantosHubProxy.paused()
        );
    }

    function migrateForwarderAtTokens(
        PantosForwarder pantosForwarder
    ) public onlyPantosForwarderRedeployerInitialized {
        Blockchain memory thisBlockchain = determineBlockchain();

        string[] memory tokenSymbols = getTokenSymbols();
        for (uint256 i = 0; i < tokenSymbols.length; i++) {
            string memory tokenSymbol = tokenSymbols[i];
            address tokenAddress = vm.parseAddress(
                getContractAddress(thisBlockchain, tokenSymbol)
            );
            PantosToken token = PantosToken(tokenAddress);
            token.pause();
            token.setPantosForwarder(address(pantosForwarder));
            token.unpause();
            console2.log(
                "%s setPantosForwarder(%s); paused=%s",
                token.name(),
                address(pantosForwarder),
                token.paused()
            );
        }
    }
}
