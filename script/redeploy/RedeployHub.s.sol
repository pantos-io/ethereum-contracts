// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;
pragma abicoder v2;

/* solhint-disable no-console*/

import "../../src/interfaces/PantosTypes.sol";

import "../helpers/PantosHubRedeployer.s.sol";

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
 *     --sig "run(address,uint256)" <oldPantosHubProxyAddress> <nextTransferId>
 */
contract RedeployHub is PantosHubRedeployer {
    function deployAndInitializeNewPantosHub(
        uint256 nextTransferId
    ) public onlyPantosHubRedeployerInitialized returns (PantosHub) {
        address primaryValidatorNodeAddress = getOldPantosHubProxy()
            .getPrimaryValidatorNode();
        PantosHub newPantosHubProxy;
        (, newPantosHubProxy, ) = deployPantosHub(nextTransferId);
        initializePantosHub(
            newPantosHubProxy,
            getPantosForwarder(),
            getPantosToken(),
            primaryValidatorNodeAddress
        );
        return newPantosHubProxy;
    }

    function migrateHubAtForwarder(
        PantosHub newPantosHubProxy
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

    function run(
        address oldPantosHubProxyAddress,
        uint256 nextTransferId
    ) public {
        vm.startBroadcast();

        initializePantosHubRedeployer(oldPantosHubProxyAddress);

        PantosHub newPantosHubProxy = deployAndInitializeNewPantosHub(
            nextTransferId
        );
        migrateHubAtForwarder(newPantosHubProxy);
        migrateTokensFromOldHubToNewHub(newPantosHubProxy);

        vm.stopBroadcast();
    }
}
