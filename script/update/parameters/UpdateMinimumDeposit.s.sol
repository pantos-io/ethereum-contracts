// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {IPantosHub} from "../../../src/interfaces/IPantosHub.sol";
import {PantosTypes} from "../../../src/interfaces/PantosTypes.sol";
import {AccessController} from "../../../src/access/AccessController.sol";

import {PantosBaseAddresses} from "./../../helpers/PantosBaseAddresses.s.sol";
import {SafeAddresses} from "../../helpers/SafeAddresses.s.sol";
import {UpdateBase} from "./UpdateBase.s.sol";

/**
 * @title UpdateMinimumDeposit
 *
 * @notice Update the minimum deposit of the service node at the Pantos Hub.
 *
 * @dev Usage
 * forge script ./script/update/parameters/UpdateMinimumDeposit.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(uint256)" <newMinimumDeposit>
 */
contract UpdateMinimumDeposit is
    PantosBaseAddresses,
    SafeAddresses,
    UpdateBase
{
    function roleActions(uint256 newMinimumDeposit) public {
        readContractAddresses(determineBlockchain());
        IPantosHub pantosHubProxy = IPantosHub(
            getContractAddress(Contract.HUB_PROXY, false)
        );
        AccessController accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        vm.startBroadcast(accessController.mediumCriticalOps());
        PantosTypes.UpdatableUint256
            memory onchainMinimumDeposit = pantosHubProxy
                .getMinimumServiceNodeDeposit();
        UpdateBase.UpdateState updateState = isInitiateOrExecute(
            onchainMinimumDeposit,
            newMinimumDeposit
        );
        if (updateState == UpdateBase.UpdateState.INITIATE) {
            pantosHubProxy.initiateMinimumServiceNodeDepositUpdate(
                newMinimumDeposit
            );
            console.log(
                "Update of minimum service node deposit initiated %s",
                newMinimumDeposit
            );
        } else if (updateState == UpdateBase.UpdateState.EXECUTE) {
            pantosHubProxy.executeMinimumServiceNodeDepositUpdate();
            console.log(
                "Update of minimum service node deposit executed %s",
                onchainMinimumDeposit.pendingValue
            );
        } else {
            revert("UpdateMinimumDeposit: Invalid update state");
        }

        vm.stopBroadcast();
        writeAllSafeInfo(accessController);
    }
}
