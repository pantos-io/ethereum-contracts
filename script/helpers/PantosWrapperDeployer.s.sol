// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;


/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

import {IPantosHub} from "../../src/interfaces/IPantosHub.sol";
import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {PantosWrapper} from "../../src/PantosWrapper.sol";
import {PantosAvaxWrapper} from "../../src/wrappers/PantosAvaxWrapper.sol";
import {PantosBnbWrapper} from "../../src/wrappers/PantosBnbWrapper.sol";
import {PantosCeloWrapper} from "../../src/wrappers/PantosCeloWrapper.sol";
import {PantosCronosWrapper} from "../../src/wrappers/PantosCronosWrapper.sol";
import {PantosEtherWrapper} from "../../src/wrappers/PantosEtherWrapper.sol";
import {PantosFantomWrapper} from "../../src/wrappers/PantosFantomWrapper.sol";
import {PantosMaticWrapper} from "../../src/wrappers/PantosMaticWrapper.sol";

import {Constants} from "./Constants.s.sol";
import {PantosBaseScript} from "./PantosBaseScript.s.sol";

abstract contract PantosWrapperDeployer is PantosBaseScript {
    PantosWrapper[] public pantosWrappers;

    function deployCoinWrappers() public {
        Blockchain memory blockchain = determineBlockchain();

        bool native = blockchain.blockchainId == BlockchainId.AVALANCHE;
        pantosWrappers.push(new PantosAvaxWrapper(native));

        native = blockchain.blockchainId == BlockchainId.BNB_CHAIN;
        pantosWrappers.push(new PantosBnbWrapper(native));

        native = blockchain.blockchainId == BlockchainId.CELO;
        pantosWrappers.push(new PantosCeloWrapper(native));

        native = blockchain.blockchainId == BlockchainId.CRONOS;
        pantosWrappers.push(new PantosCronosWrapper(native));

        native = blockchain.blockchainId == BlockchainId.ETHEREUM;
        pantosWrappers.push(new PantosEtherWrapper(native));

        native = blockchain.blockchainId == BlockchainId.FANTOM;
        pantosWrappers.push(new PantosFantomWrapper(native));

        native = blockchain.blockchainId == BlockchainId.POLYGON;
        pantosWrappers.push(new PantosMaticWrapper(native));

        console2.log("All %s wrappers deployed", pantosWrappers.length);
    }

    function initializePantosWrappers(
        IPantosHub pantosHubProxy,
        PantosForwarder pantosForwarder
    ) public {
        for (uint256 i; i < pantosWrappers.length; i++) {
            pantosWrappers[i].setPantosForwarder(address(pantosForwarder));

            pantosHubProxy.registerToken(
                address(pantosWrappers[i]),
                Constants.MINIMUM_TOKEN_STAKE
            );
            pantosWrappers[i].unpause();
            console2.log(
                "%s initialized; paused=%s",
                pantosWrappers[i].name(),
                pantosWrappers[i].paused()
            );
        }
    }
}
