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
contract AccessController is AccessControl, PantosRoles {
    /**
     * @notice Initialize access controller with roles.
     *
     * @param _pauser Address of the pauser role.
     * @param _deployer Address of the deployer role.
     * @param _mediumCriticalOps Address of the medium critical operations role.
     * @param _superCriticalOps Address of the super critical operations role.
     */
    constructor(
        address _pauser,
        address _deployer,
        address _mediumCriticalOps,
        address _superCriticalOps
    ) {
        _grantRole(PAUSER, _pauser);
        _grantRole(DEPLOYER, _deployer);
        _grantRole(MEDIUM_CRITICAL_OPS, _mediumCriticalOps);
        _grantRole(SUPER_CRITICAL_OPS, _superCriticalOps);
    }
}
