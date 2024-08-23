// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {PantosToken} from "../src/PantosToken.sol";
import {PantosForwarder} from "../src/PantosForwarder.sol";
import {AccessController} from "../src/access/AccessController.sol";

import {PantosTokenDeployer} from "./helpers/PantosTokenDeployer.s.sol";
import {Constants} from "./helpers/Constants.s.sol";

contract DeployLocalPantosTokenStandalone is PantosTokenDeployer {
    function run(address forwarder, address accessControllerAddress) external {
        vm.startBroadcast();

        PantosToken pantosToken = deployPantosToken(
            Constants.INITIAL_SUPPLY_PAN,
            AccessController(accessControllerAddress)
        );
        initializePantosToken(pantosToken, PantosForwarder(forwarder));

        vm.stopBroadcast();
    }
}
