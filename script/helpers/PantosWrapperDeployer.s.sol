// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;
pragma abicoder v2;

/* solhint-disable no-console*/

import "../../src/contracts/PantosHub.sol";
import "../../src/contracts/PantosForwarder.sol";
import "../../src/contracts/PantosWrapper.sol";
import "../../src/contracts/wrappers/PantosAvaxWrapper.sol";
import "../../src/contracts/wrappers/PantosBnbWrapper.sol";
import "../../src/contracts/wrappers/PantosCeloWrapper.sol";
import "../../src/contracts/wrappers/PantosCronosWrapper.sol";
import "../../src/contracts/wrappers/PantosEtherWrapper.sol";
import "../../src/contracts/wrappers/PantosFantomWrapper.sol";
import "../../src/contracts/wrappers/PantosMaticWrapper.sol";

import "./Constants.s.sol";
import "./PantosBaseScript.s.sol";

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
        PantosHub pantosHubProxy,
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
