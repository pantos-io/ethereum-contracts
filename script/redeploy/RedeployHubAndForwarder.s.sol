// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;
pragma abicoder v2;

/* solhint-disable no-console*/

import "../helpers/PantosForwarderRedeployer.s.sol";
import "../helpers/PantosHubRedeployer.s.sol";

/**
 * @title RedeployHubAndForwarder
 *
 * @notice Redeploy the Pantos Hub and the Pantos Forwarder.
 * To ensure correct functionality of the newly deployed Pantos Hub
 * and Pantos Forwarder within the Pantos protocol, the following
 * steps are incorporated into this script:
 *
 * 1. Retrieve the validator node addresses from the previous Pantos Hub
 * and Forwarder and configure it in the new Pantos Hub and Forwarder.
 * 2. Retrieve the Pantos Forwarder address from the previous Pantos Hub and
 * configure it in the new Pantos Hub.
 * 3. Retrieve the Pantos token address from the previous Pantos Hub and
 * configure it in the new Pantos Hub and the Pantos Forwarder.
 * 4. Configure the new Pantos Hub at the Pantos Forwarder.
 * 5. Configure the new Pantos Forwarder at the Pantos Hub.
 * 5. Configure the new Pantos Forwarder at Pantos, Best and Wrapper tokens.
 * 6. Migrate the tokens owned by the sender account from the old Pantos Hub
 * to the new one.
 *
 * @dev Usage
 * forge script ./script/redeploy/RedeployHubAndForwarder.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "run(address,uint256)" <oldPantosHubProxyAddress> <nextTransferId>
 */
contract RedeployHubAndForwarder is
    PantosHubRedeployer,
    PantosForwarderRedeployer
{
    function deployAndInitializeHubAndForwarder(
        uint256 nextTransferId
    )
        public
        onlyPantosHubRedeployerInitialized
        returns (PantosHub, PantosForwarder)
    {
        address primaryValidatorNodeAddress = getOldPantosHubProxy()
            .getPrimaryValidatorNode();
        address[] memory validatorNodeAddresses = PantosForwarder(
            getOldPantosHubProxy().getPantosForwarder()
        ).getValidatorNodes();
        PantosHub newPantosHubProxy;
        (, newPantosHubProxy, ) = deployPantosHub(nextTransferId);
        PantosForwarder newPantosForwarder = deployPantosForwarder();
        initializePantosHub(
            newPantosHubProxy,
            newPantosForwarder,
            getPantosToken(),
            primaryValidatorNodeAddress
        );
        initializePantosForwarder(
            newPantosForwarder,
            newPantosHubProxy,
            getPantosToken(),
            validatorNodeAddresses
        );
        return (newPantosHubProxy, newPantosForwarder);
    }

    function run(
        address oldPantosHubProxyAddress,
        uint256 nextTransferId
    ) public {
        vm.startBroadcast();

        initializePantosHubRedeployer(oldPantosHubProxyAddress);
        initializePantosForwarderRedeployer(oldPantosHubProxyAddress);

        PantosHub newPantosHubProxy;
        PantosForwarder newPantosForwarder;
        (
            newPantosHubProxy,
            newPantosForwarder
        ) = deployAndInitializeHubAndForwarder(nextTransferId);
        migrateTokensFromOldHubToNewHub(newPantosHubProxy);
        migrateForwarderAtTokens(newPantosForwarder);

        vm.stopBroadcast();
    }
}
