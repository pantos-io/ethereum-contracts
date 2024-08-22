// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {AccessController} from "../../src/access/AccessController.sol";
import {PantosWrapper} from "../../src/PantosWrapper.sol";
import {PantosAvaxWrapper} from "../../src/wrappers/PantosAvaxWrapper.sol";
import {PantosBnbWrapper} from "../../src/wrappers/PantosBnbWrapper.sol";
import {PantosCeloWrapper} from "../../src/wrappers/PantosCeloWrapper.sol";
import {PantosCronosWrapper} from "../../src/wrappers/PantosCronosWrapper.sol";
import {PantosEtherWrapper} from "../../src/wrappers/PantosEtherWrapper.sol";
import {PantosFantomWrapper} from "../../src/wrappers/PantosFantomWrapper.sol";
import {PantosMaticWrapper} from "../../src/wrappers/PantosMaticWrapper.sol";

import {PantosBaseScript} from "./PantosBaseScript.s.sol";

abstract contract PantosWrapperDeployer is PantosBaseScript {
    PantosWrapper[] public pantosWrappers;

    function deployCoinWrappers(AccessController accessController) public {
        Blockchain memory blockchain = determineBlockchain();

        bool native = blockchain.blockchainId == BlockchainId.AVALANCHE;
        pantosWrappers.push(
            new PantosAvaxWrapper(native, address(accessController))
        );

        native = blockchain.blockchainId == BlockchainId.BNB_CHAIN;
        pantosWrappers.push(
            new PantosBnbWrapper(native, address(accessController))
        );

        native = blockchain.blockchainId == BlockchainId.CELO;
        pantosWrappers.push(
            new PantosCeloWrapper(native, address(accessController))
        );

        native = blockchain.blockchainId == BlockchainId.CRONOS;
        pantosWrappers.push(
            new PantosCronosWrapper(native, address(accessController))
        );

        native = blockchain.blockchainId == BlockchainId.ETHEREUM;
        pantosWrappers.push(
            new PantosEtherWrapper(native, address(accessController))
        );

        native = blockchain.blockchainId == BlockchainId.FANTOM;
        pantosWrappers.push(
            new PantosFantomWrapper(native, address(accessController))
        );

        native = blockchain.blockchainId == BlockchainId.POLYGON;
        pantosWrappers.push(
            new PantosMaticWrapper(native, address(accessController))
        );

        console2.log("All %s wrappers deployed", pantosWrappers.length);
    }

    function initializePantosWrappers(
        IPantosHub pantosHubProxy,
        PantosForwarder pantosForwarder
    ) public {
        for (uint256 i; i < pantosWrappers.length; i++) {
            pantosWrappers[i].setPantosForwarder(address(pantosForwarder));

            pantosHubProxy.registerToken(address(pantosWrappers[i]));
            pantosWrappers[i].unpause();
            console2.log(
                "%s initialized; paused=%s",
                pantosWrappers[i].name(),
                pantosWrappers[i].paused()
            );
        }
    }
}
