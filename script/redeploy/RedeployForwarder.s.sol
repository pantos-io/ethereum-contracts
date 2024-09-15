// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/

import {AccessController} from "../../src/access/AccessController.sol";
import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {IPantosToken} from "../../src/interfaces/IPantosToken.sol";
import {PantosToken} from "../../src/PantosToken.sol";
import {PantosWrapper} from "../../src/PantosWrapper.sol";

import {PantosForwarder} from "../../src/PantosForwarder.sol";

import {PantosBaseAddresses} from "../helpers/PantosBaseAddresses.s.sol";
import {PantosForwarderRedeployer} from "../helpers/PantosForwarderRedeployer.s.sol";

/**
 * @title RedeployForwarder
 *
 * @notice Redeploy the Pantos Forwarder
 * To ensure correct functionality of the newly deployed Pantos Forwarder
 * within the Pantos protocol, the following steps are incorporated into
 * this script:
 *
 * 1. Retrieve the validator node addresses from the previous Pantos
 * Forwarder and configure it in the new Pantos Forwarder.
 * 2. Retrieve the Pantos token address from the Pantos Hub and
 * configure it in the new Pantos Forwarder.
 * 3. Configure the new Pantos Forwarder at the Pantos Hub.
 * 4. Configure the new Pantos Forwarder at Pantos, Best and Wrapper tokens.
 *
 * @dev Usage
 * forge script ./script/redeploy/RedeployForwarder.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "run(address)" <pantosHubProxyAddress>
 */
contract RedeployForwarder is PantosBaseAddresses, PantosForwarderRedeployer {
    AccessController accessController;
    PantosForwarder newPantosForwarder;
    IPantosHub pantosHub;
    PantosWrapper[] tokens;

    function deploy(address accessControllerAddress) public {
        accessController = AccessController(accessControllerAddress);
        vm.broadcast(accessController.deployer());
        newPantosForwarder = deployPantosForwarder(accessController);

        exportRedeployedContractAddresses();
    }

    function roleActions() public {
        importContractAddresses();
        PantosForwarder oldForwarder = PantosForwarder(
            pantosHub.getPantosForwarder()
        );

        address[] memory validatorNodeAddresses = tryGetValidatorNodes(
            oldForwarder
        );
        vm.broadcast(accessController.superCriticalOps());
        initializePantosForwarder(
            newPantosForwarder,
            pantosHub,
            PantosToken(pantosHub.getPantosToken()),
            validatorNodeAddresses
        );

        // Pause pantos Hub and old forwarder
        vm.startBroadcast(accessController.pauser());
        pauseForwarder(oldForwarder);
        pantosHub.pause();
        vm.stopBroadcast();

        vm.broadcast(accessController.superCriticalOps());
        migrateForwarderAtHub(newPantosForwarder, pantosHub);

        // migrate new Forwarder at tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.startBroadcast(accessController.pauser());
            tokens[i].pause();

            vm.broadcast(accessController.superCriticalOps());
            migrateNewForwarderAtToken(newPantosForwarder, tokens[i]);
        }
        // update json with new forwarder
        overrideWithRedeployedAddresses();
    }

    function exportRedeployedContractAddresses() internal {
        ContractAddress[] memory contractAddresses = new ContractAddress[](1);
        contractAddresses[0] = ContractAddress(
            Contract.FORWARDER,
            address(newPantosForwarder)
        );
        exportContractAddresses(contractAddresses, true);
    }

    function importContractAddresses() public {
        readContractAddresses(thisBlockchain);
        readRedeployedContractAddresses();

        // New items
        newPantosForwarder = PantosForwarder(
            payable(getContractAddress(Contract.FORWARDER, true))
        );

        // Old items
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );

        pantosHub = IPantosHub(
            payable(getContractAddress(Contract.HUB_PROXY, false))
        );

        string[] memory tokenSymbols = getTokenSymbols();
        for (uint256 i = 0; i < tokenSymbols.length; i++) {
            Contract contract_ = _keysToContracts[tokenSymbols[i]];
            address token = getContractAddress(contract_, false);
            tokens.push(PantosWrapper(token));
        }
    }
}
