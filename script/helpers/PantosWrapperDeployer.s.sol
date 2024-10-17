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
import {PantosPolWrapper} from "../../src/wrappers/PantosPolWrapper.sol";
import {PantosSWrapper} from "../../src/wrappers/PantosSWrapper.sol";

import {PantosBaseScript} from "./PantosBaseScript.s.sol";

abstract contract PantosWrapperDeployer is PantosBaseScript {
    function deployCoinWrappers(
        AccessController accessController
    ) public returns (PantosWrapper[] memory) {
        PantosWrapper[] memory pantosWrappers = new PantosWrapper[](7);
        Blockchain memory blockchain = determineBlockchain();

        bool native = blockchain.blockchainId == BlockchainId.AVALANCHE;
        pantosWrappers[0] = new PantosAvaxWrapper(
            native,
            address(accessController)
        );

        native = blockchain.blockchainId == BlockchainId.BNB_CHAIN;
        pantosWrappers[1] = new PantosBnbWrapper(
            native,
            address(accessController)
        );

        native = blockchain.blockchainId == BlockchainId.CELO;
        pantosWrappers[2] = new PantosCeloWrapper(
            native,
            address(accessController)
        );

        native = blockchain.blockchainId == BlockchainId.CRONOS;
        pantosWrappers[3] = new PantosCronosWrapper(
            native,
            address(accessController)
        );

        native = blockchain.blockchainId == BlockchainId.ETHEREUM;
        pantosWrappers[4] = new PantosEtherWrapper(
            native,
            address(accessController)
        );

        native = blockchain.blockchainId == BlockchainId.SONIC;
        pantosWrappers[5] = new PantosSWrapper(
            native,
            address(accessController)
        );

        native = blockchain.blockchainId == BlockchainId.POLYGON;
        pantosWrappers[6] = new PantosPolWrapper(
            native,
            address(accessController)
        );

        console2.log("All %s wrappers deployed", pantosWrappers.length);

        return pantosWrappers;
    }

    function initializePantosWrappers(
        IPantosHub pantosHubProxy,
        PantosForwarder pantosForwarder,
        PantosWrapper[] memory pantosWrappers
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
