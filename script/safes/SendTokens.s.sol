// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {AccessController} from "../../src/access/AccessController.sol";
import {PantosToken} from "../../src/PantosToken.sol";

import {PantosBaseAddresses} from "./../helpers/PantosBaseAddresses.s.sol";
import {SafeAddresses} from "./../helpers/SafeAddresses.s.sol";

/**
 * @title Send tokens
 *
 * @notice Send tokens owned by the Gnosis Safe (Pantos role).
 *
 * @dev Usage
 * forge script ./script/update/parameters/SendTokens.s.sol --rpc-url <rpc alias>
 *      --sig "roleActions(string,address,address,uint256)" <roleName> \
 *      <tokenAddress> <receiver> <amount>
 */
contract SendTokens is PantosBaseAddresses, SafeAddresses {
    AccessController accessController;
    PantosToken pantosToken;
    IERC20 token;

    address roleAddress;

    function roleActions(
        string memory roleName,
        address tokenAddress,
        address receiver,
        uint256 amount
    ) public {
        readContractAddresses(determineBlockchain());
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );
        token = IERC20(tokenAddress);
        Role role = getRole(roleName);

        if (role == Role.PAUSER) {
            roleAddress = accessController.pauser();
        } else if (role == Role.DEPLOYER) {
            roleAddress = accessController.deployer();
        } else if (role == Role.MEDIUM_CRITICAL_OPS) {
            roleAddress = accessController.mediumCriticalOps();
        } else if (role == Role.SUPER_CRITICAL_OPS) {
            roleAddress = accessController.superCriticalOps();
        } else {
            revert("Role not found");
        }

        vm.broadcast(roleAddress);
        token.transfer(receiver, amount);

        console.log(
            "%s tokens (%s) sent to %s",
            amount,
            tokenAddress,
            receiver
        );

        writeAllSafeInfo(accessController);
    }
}
