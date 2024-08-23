// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title Access control library
 *
 * @notice Library to manage access control for the Pantos Hub diamond.
 */
library LibAccessControl {
    bytes32 constant ACCESS_CONTROL_STORAGE_POSITION =
        keccak256("pantos.access.control");

    struct AccessControlStorage {
        IAccessControl accessController;
    }

    /**
     * @notice Get the access control storage slot.
     *
     * @return acs Access control storage slot.
     */
    function accessControlStorage()
        internal
        pure
        returns (AccessControlStorage storage acs)
    {
        bytes32 position = ACCESS_CONTROL_STORAGE_POSITION;
        assembly {
            acs.slot := position
        }
    }

    /**
     * @notice Set the access controller.
     *
     * @param accessController_ Address of the access controller.
     */
    function setAccessController(address accessController_) internal {
        AccessControlStorage storage acs = accessControlStorage();
        acs.accessController = IAccessControl(accessController_);
    }
}
