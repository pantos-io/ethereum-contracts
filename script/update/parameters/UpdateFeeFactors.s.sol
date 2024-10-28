// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {IPantosHub} from "../../../src/interfaces/IPantosHub.sol";
import {PantosTypes} from "../../../src/interfaces/PantosTypes.sol";
import {AccessController} from "../../../src/access/AccessController.sol";

import {PantosBaseScript} from "../../helpers/PantosHubDeployer.s.sol";
import {SafeAddresses} from "../../helpers/SafeAddresses.s.sol";
import {UpdateBase} from "./UpdateBase.s.sol";

/**
 * @title UpdateFeeFactors
 *
 * @notice Update the fee factors at the Pantos Hub.
 *
 * @dev Usage
 * forge script ./script/update/parameters/UpdateFeeFactors.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(address,address)" <accessControllerAddress> \
 *      <pantosHubProxy>
 */
contract UpdateFeeFactors is PantosBaseScript, SafeAddresses, UpdateBase {
    function roleActions(
        address accessControllerAddress,
        address pantosHubProxyAddress
    ) public {
        IPantosHub pantosHubProxy = IPantosHub(pantosHubProxyAddress);
        AccessController accessController = AccessController(
            accessControllerAddress
        );
        vm.startBroadcast(accessController.mediumCriticalOps());

        for (uint256 i; i < getBlockchainsLength(); i++) {
            Blockchain memory blockchain = getBlockchainById(BlockchainId(i));
            if (!blockchain.skip) {
                uint256 blockchainId = uint256(blockchain.blockchainId);
                PantosTypes.UpdatableUint256
                    memory onChainFeeFactor = pantosHubProxy
                        .getValidatorFeeFactor(blockchainId);
                UpdateBase.UpdateState updateState = isInitiateOrExecute(
                    onChainFeeFactor,
                    blockchain.feeFactor
                );
                if (updateState == UpdateBase.UpdateState.INITIATE) {
                    pantosHubProxy.initiateValidatorFeeFactorUpdate(
                        blockchainId,
                        blockchain.feeFactor
                    );
                    console.log(
                        "Update of fee factor for blockchain %s initiated %s",
                        blockchain.name,
                        blockchain.feeFactor
                    );
                } else if (updateState == UpdateBase.UpdateState.EXECUTE) {
                    pantosHubProxy.executeValidatorFeeFactorUpdate(
                        blockchainId
                    );
                    console.log(
                        "Update of fee factor for blockchain %s executed %s",
                        blockchain.name,
                        onChainFeeFactor.pendingValue
                    );
                } else {
                    revert("UpdateFeeFactors: Invalid update state");
                }
            }
        }

        vm.stopBroadcast();
        writeAllSafeInfo(accessController);
    }
}
