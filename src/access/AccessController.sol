// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {PantosRoles} from "./PantosRoles.sol";

/**
 * @title Access controller
 *
 * @notice Access control contract to manage Pantos roles and permissions.
 */
contract AccessController is AccessControl {
    address public immutable pauser;
    address public immutable deployer;
    address public immutable mediumCriticalOps;
    address public immutable superCriticalOps;

    /**
     * @notice Initialize access controller with roles.
     *
     * @param pauser_ Address of the pauser role.
     * @param deployer_ Address of the deployer role.
     * @param mediumCriticalOps_ Address of the medium critical operations role.
     * @param superCriticalOps_ Address of the super critical operations role.
     */
    constructor(
        address pauser_,
        address deployer_,
        address mediumCriticalOps_,
        address superCriticalOps_
    ) {
        pauser = pauser_;
        deployer = deployer_;
        mediumCriticalOps = mediumCriticalOps_;
        superCriticalOps = superCriticalOps_;

        _grantRole(PantosRoles.PAUSER, pauser);
        _grantRole(PantosRoles.DEPLOYER, deployer);
        _grantRole(PantosRoles.MEDIUM_CRITICAL_OPS, mediumCriticalOps);
        _grantRole(PantosRoles.SUPER_CRITICAL_OPS, superCriticalOps);
    }
}
