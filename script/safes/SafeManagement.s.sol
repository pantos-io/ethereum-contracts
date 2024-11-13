// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOwnerManager} from "@safe/interfaces/IOwnerManager.sol";
import {OwnerManager} from "@safe/base/OwnerManager.sol";

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {AccessController} from "../../src/access/AccessController.sol";
import {PantosToken} from "../../src/PantosToken.sol";

import {PantosBaseAddresses} from "./../helpers/PantosBaseAddresses.s.sol";
import {SafeAddresses} from "./../helpers/SafeAddresses.s.sol";

/**
 * @title Safe Management
 *
 * @notice Management of the Gnosis Safe operations.
 *
 * @dev Usage
 * 1. Add an owner with a threshold
 * forge script ./script/safes/SafeManagement.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force --sig \
 *     "addOwnerWithThreshold(string,address,uint256)" \
 *     <roleName> <newOwner> <newThreshold>
 *
 * 2. Remove an owner with a threshold
 * forge script ./script/safes/SafeManagement.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force --sig \
 *     "removeOwnerWithThreshold(string,address,uint256)" \
 *     <roleName> <owner> <newThreshold>
 *
 * 3. Swap an owner
 * forge script ./script/safes/SafeManagement.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force --sig \
 *     "swapOwner(string,address,address)" <roleName> <oldOwner> <newOwner>
 *
 * 4. Change the threshold
 * forge script ./script/safes/SafeManagement.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force --sig \
 *     "changeThreshold(string,uint256)" <roleName> <newThreshold>
 */
contract SafeManagement is PantosBaseAddresses, SafeAddresses {
    AccessController accessController;
    IOwnerManager ownerManager;
    address roleAddress;
    address internal constant SENTINEL_OWNERS = address(0x1);

    function initializeDependencies(string memory roleName) internal {
        readContractAddresses(determineBlockchain());
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        roleAddress = getRoleAddress(roleName);
        writeAllSafeInfo(accessController);
        ownerManager = IOwnerManager(roleAddress);
    }

    function getRoleAddress(
        string memory roleName
    ) internal view returns (address) {
        Role role = getRole(roleName);

        if (role == Role.PAUSER) {
            return accessController.pauser();
        } else if (role == Role.DEPLOYER) {
            return accessController.deployer();
        } else if (role == Role.MEDIUM_CRITICAL_OPS) {
            return accessController.mediumCriticalOps();
        } else if (role == Role.SUPER_CRITICAL_OPS) {
            return accessController.superCriticalOps();
        } else {
            revert("Role not found");
        }
    }

    function findPreviousOwner(
        address owner,
        address[] memory owners
    ) internal pure returns (address) {
        if (owners[0] == owner) {
            return SENTINEL_OWNERS;
        }
        for (uint256 i = 1; i < owners.length; i++) {
            if (owners[i] == owner) {
                return owners[i - 1];
            }
        }
        revert("The given address is not an owner of the Safe");
    }

    function addOwnerWithThreshold(
        string memory roleName,
        address newOwner,
        uint256 newThreshold
    ) public {
        require(
            newOwner != address(0) && newOwner != SENTINEL_OWNERS,
            "Invalid owner address"
        );
        initializeDependencies(roleName);
        require(!ownerManager.isOwner(newOwner), "Owner already exists");

        vm.broadcast(roleAddress);
        ownerManager.addOwnerWithThreshold(newOwner, newThreshold);
        console.log(
            "Owner %s added with threshold %d",
            newOwner,
            newThreshold
        );
    }

    function removeOwnerWithThreshold(
        string memory roleName,
        address owner,
        uint256 newThreshold
    ) public {
        require(
            owner != address(0) && owner != SENTINEL_OWNERS,
            "Invalid owner address"
        );
        initializeDependencies(roleName);
        require(ownerManager.isOwner(owner), "Owner does not exist");
        address[] memory owners = ownerManager.getOwners();
        require(
            owners.length - 1 >= newThreshold,
            "Threshold cannot be reached anymore"
        );
        require(owners.length > 1, "Cannot remove the last owner");
        address previousOwner = findPreviousOwner(owner, owners);

        vm.broadcast(roleAddress);
        ownerManager.removeOwner(previousOwner, owner, newThreshold);
        console.log("Owner %s removed with threshold %s", owner, newThreshold);
    }

    function swapOwner(
        string memory roleName,
        address oldOwner,
        address newOwner
    ) public {
        require(
            oldOwner != address(0) && oldOwner != SENTINEL_OWNERS,
            "Invalid old owner address"
        );
        require(
            newOwner != address(0) && newOwner != SENTINEL_OWNERS,
            "Invalid new owner address"
        );
        initializeDependencies(roleName);
        require(!ownerManager.isOwner(newOwner), "New owner already exists");
        require(ownerManager.isOwner(oldOwner), "Old owner does not exist");
        address[] memory owners = ownerManager.getOwners();
        address previousOwner = findPreviousOwner(oldOwner, owners);

        vm.broadcast(roleAddress);
        ownerManager.swapOwner(previousOwner, oldOwner, newOwner);
        console.log("Owner %s swapped with %s", oldOwner, newOwner);
    }

    function changeThreshold(
        string memory roleName,
        uint256 newThreshold
    ) public {
        require(newThreshold > 0, "Threshold must be greater than 0");
        initializeDependencies(roleName);
        uint256 oldThreshold = ownerManager.getThreshold();
        require(newThreshold != oldThreshold, "Threshold is the same");
        address[] memory owners = ownerManager.getOwners();
        require(
            owners.length >= newThreshold,
            "Threshold cannot be reached anymore"
        );

        vm.broadcast(roleAddress);
        ownerManager.changeThreshold(newThreshold);
        console.log("Threshold %s changed to %d", oldThreshold, newThreshold);
    }
}
