// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Pantos RBAC
 */
abstract contract PantosRBAC {
    IAccessControl private immutable _accessController;

    /**
     * @notice Initialize Pantos RBAC with roles.
     *
     * @param accessControllerAddress Address of the access controller.
     */
    constructor(address accessControllerAddress) {
        _accessController = IAccessControl(accessControllerAddress);
    }

    /**
     * @notice Modifier making sure that the function can only be called by the
     * authorized role.
     */
    modifier onlyRole(bytes32 _role) {
        require(
            _accessController.hasRole(_role, msg.sender),
            "PantosRBAC: caller doesn't have role"
        );
        _;
    }
}
