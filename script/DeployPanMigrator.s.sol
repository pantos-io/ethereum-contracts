// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PantosToken} from "../src/PantosToken.sol";
import {AccessController} from "../src/access/AccessController.sol";
import {PantosTokenMigrator} from "../src/PantosTokenMigrator.sol";

import {PantosTokenMigratorDeployer} from "./helpers/PantosTokenMigratorDeployer.s.sol";
import {PantosTokenDeployer} from "./helpers/PantosTokenDeployer.s.sol";
import {AccessControllerDeployer} from "./helpers/AccessControllerDeployer.s.sol";
import {PantosBaseAddresses} from "./helpers/PantosBaseAddresses.s.sol";
import {SafeAddresses} from "./helpers/SafeAddresses.s.sol";

/**
 * @title Deploy PAN migrator
 *
 * @notice Deploy the PAN migrator along with its dependencies:
 *     The PAN token and the Access Controller.
 *
 * @dev Usage
 * Deploy by any gas paying account:
 * forge script ./script/DeployPanMigrator.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force --sig \
 *     "deploy(address)" <oldTokenAddress>
 */
contract DeployPanMigrator is
    PantosBaseAddresses,
    SafeAddresses,
    AccessControllerDeployer,
    PantosTokenDeployer,
    PantosTokenMigratorDeployer
{
    AccessController accessController;
    PantosToken pantosToken;
    PantosTokenMigrator pantosTokenMigrator;

    function deploy(address oldTokenAddress) public {
        vm.startBroadcast();
        readRoleAddresses();
        address pauser = getRoleAddress(Role.PAUSER);
        address deployer = getRoleAddress(Role.DEPLOYER);
        address mediumCriticalOps = getRoleAddress(Role.MEDIUM_CRITICAL_OPS);
        address superCriticalOps = getRoleAddress(Role.SUPER_CRITICAL_OPS);
        accessController = deployAccessController(
            pauser,
            deployer,
            mediumCriticalOps,
            superCriticalOps
        );
        pantosToken = deployPantosToken(
            IERC20(oldTokenAddress).totalSupply(),
            accessController
        );
        pantosTokenMigrator = deployPantosTokenMigrator(
            oldTokenAddress,
            address(pantosToken)
        );
        vm.stopBroadcast();

        exportAllContractAddresses();
    }

    function exportAllContractAddresses() internal {
        ContractAddress[] memory contractAddresses = new ContractAddress[](3);
        contractAddresses[0] = ContractAddress(
            Contract.ACCESS_CONTROLLER,
            address(accessController)
        );
        contractAddresses[1] = ContractAddress(
            Contract.PAN,
            address(pantosToken)
        );
        contractAddresses[2] = ContractAddress(
            Contract.PAN_MIGRATOR,
            address(pantosTokenMigrator)
        );
        exportContractAddresses(contractAddresses, false);
    }
}
