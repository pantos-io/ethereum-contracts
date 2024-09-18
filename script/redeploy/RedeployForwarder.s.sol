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
import {SafeAddresses} from "../helpers/SafeAddresses.s.sol";

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
 * 1. Deploy by any gas paying account:
 * forge script ./script/redeploy/RedeployForwarder.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "deploy(address)" <accessControllerAddress>
 * 2. Simulate roleActions to be later signed by appropriate roles
 *  forge script ./script/redeploy/RedeployForwarder.s.sol \
 *     --rpc-url <rpc alias> --sig "roleActions() -vvvv"
 */
contract RedeployForwarder is
    PantosBaseAddresses,
    SafeAddresses,
    PantosForwarderRedeployer
{
    AccessController accessController;
    PantosForwarder newPantosForwarder;
    IPantosHub pantosHub;
    PantosWrapper[] tokens;

    function deploy(address accessControllerAddress) public {
        accessController = AccessController(accessControllerAddress);
        vm.startBroadcast();
        newPantosForwarder = deployPantosForwarder(accessController);
        vm.stopBroadcast();

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
        vm.startBroadcast(accessController.superCriticalOps());
        initializePantosForwarder(
            newPantosForwarder,
            pantosHub,
            PantosToken(pantosHub.getPantosToken()),
            validatorNodeAddresses
        );
        vm.stopBroadcast();

        // Pause pantos Hub and old forwarder
        vm.startBroadcast(accessController.pauser());
        pauseForwarder(oldForwarder);
        pantosHub.pause();
        vm.stopBroadcast();

        vm.startBroadcast(accessController.superCriticalOps());
        migrateForwarderAtHub(newPantosForwarder, pantosHub);
        vm.stopBroadcast();

        // migrate new Forwarder at tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.broadcast(accessController.pauser());
            tokens[i].pause();

            vm.startBroadcast(accessController.superCriticalOps());
            migrateNewForwarderAtToken(newPantosForwarder, tokens[i]);
            vm.stopBroadcast();
        }
        // update json with new forwarder
        overrideWithRedeployedAddresses();
        writeAllSafeInfo(accessController);
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
        readContractAddresses(determineBlockchain());
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
