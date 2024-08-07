// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

import {AccessController} from "../../src/access/AccessController.sol";

abstract contract AccessControllerDeployer {
    function deployAccessController(
        address pauser,
        address deployer,
        address mediumCriticalOps,
        address superCriticalOps
    ) public returns (AccessController) {
        AccessController accessController = new AccessController(
            pauser,
            deployer,
            mediumCriticalOps,
            superCriticalOps
        );
        console2.log(
            "AccessController deployed; address=%s; deployer=%s",
            address(accessController),
            deployer
        );
        console2.log(
            "AccessController: pauser=%s; mediumCriticalOps=%s; "
            "superCriticalOps=%s",
            pauser,
            mediumCriticalOps,
            superCriticalOps
        );
        return accessController;
    }
}
