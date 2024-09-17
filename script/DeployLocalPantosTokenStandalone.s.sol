// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {PantosToken} from "../src/PantosToken.sol";
import {PantosForwarder} from "../src/PantosForwarder.sol";
import {AccessController} from "../src/access/AccessController.sol";

import {PantosTokenDeployer} from "./helpers/PantosTokenDeployer.s.sol";
import {Constants} from "./helpers/Constants.s.sol";

contract DeployLocalPantosTokenStandalone is PantosTokenDeployer {
    function deploy(address accessControllerAddress) public {
        vm.startBroadcast();
        deployPantosToken(
            Constants.INITIAL_SUPPLY_PAN,
            AccessController(accessControllerAddress)
        );
        vm.stopBroadcast();
    }

    function roleActions(
        address accessControllerAddress,
        address pantosTokenAddress,
        address pantosForwarderAddress
    ) external {
        AccessController accessController = AccessController(
            accessControllerAddress
        );
        PantosForwarder pantosForwarder = PantosForwarder(
            pantosForwarderAddress
        );
        PantosToken pantosToken = PantosToken(pantosTokenAddress);

        vm.startBroadcast(accessController.superCriticalOps());
        initializePantosToken(pantosToken, pantosForwarder);
        vm.stopBroadcast();
    }
}
