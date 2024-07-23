// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;


/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

import {PantosTypes} from "../../src/interfaces/PantosTypes.sol";
import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {PantosForwarder} from "../../src/PantosForwarder.sol";

import {PantosHubRedeployer} from "../helpers/PantosHubRedeployer.s.sol";

/**
 * @title RedeployHub
 *
 * @notice Redeploy the Pantos Hub.
 * To ensure correct functionality of the newly deployed Pantos Hub within the
 * Pantos protocol, the following steps are incorporated into this script:
 *
 * 1. Retrieve the primary validator node address from the previous
 * Pantos Hub and configure it in the new Pantos Hub.
 * 2. Retrieve the Pantos Forwarder address from the previous Pantos Hub and
 * configure it in the new Pantos Hub.
 * 3. Retrieve the Pantos token address from the previous Pantos Hub and
 * configure it in the new Pantos Hub.
 * 4. Configure the new Pantos Hub at the Pantos Forwarder.
 * 5. Migrate the tokens owned by the sender account from the old Pantos Hub
 * to the new one.
 *
 * @dev Usage
 * forge script ./script/redeploy/RedeployHub.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "run(address,uint256)" <oldPantosHubProxyAddress>
 */
contract RedeployHub is PantosHubRedeployer {
    function deployAndInitializeNewPantosHub()
        public
        onlyPantosHubRedeployerInitialized
        returns (IPantosHub)
    {
        IPantosHub oldPantosHubProxy = getOldPantosHubProxy();
        if (!oldPantosHubProxy.paused()) {
            oldPantosHubProxy.pause();
        }
        address primaryValidatorNodeAddress = oldPantosHubProxy
            .getPrimaryValidatorNode();
        uint256 nextTransferId = oldPantosHubProxy.getNextTransferId();

        (IPantosHub newPantosHubProxy, ) = deployPantosHub(nextTransferId);
        initializePantosHub(
            newPantosHubProxy,
            getPantosForwarder(),
            getPantosToken(),
            primaryValidatorNodeAddress
        );
        return newPantosHubProxy;
    }

    function migrateHubAtForwarder(
        IPantosHub newPantosHubProxy
    ) public onlyPantosHubRedeployerInitialized {
        PantosForwarder pantosForwarder = getPantosForwarder();
        pantosForwarder.pause();
        pantosForwarder.setPantosHub(address(newPantosHubProxy));
        pantosForwarder.unpause();
        console2.log(
            "PantosForwarder.setPantosHub(%s); paused=%s",
            address(newPantosHubProxy),
            pantosForwarder.paused()
        );
    }

    function run(address oldPantosHubProxyAddress) public {
        vm.startBroadcast();

        initializePantosHubRedeployer(oldPantosHubProxyAddress);

        IPantosHub newPantosHubProxy = deployAndInitializeNewPantosHub();
        migrateHubAtForwarder(newPantosHubProxy);
        migrateTokensFromOldHubToNewHub(newPantosHubProxy);

        vm.stopBroadcast();
    }
}
