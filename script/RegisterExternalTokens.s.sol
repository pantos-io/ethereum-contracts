// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

import {AccessController} from "../src/access/AccessController.sol";
import {PantosTypes} from "../src/interfaces/PantosTypes.sol";
import {IPantosHub} from "../src/interfaces/IPantosHub.sol";
import {PantosBaseAddresses} from "./helpers/PantosBaseAddresses.s.sol";

/**
 * @title RegisterExternalTokens
 *
 * @notice Register newly deployed external tokens at the Pantos hub of an
 * Ethereum-compatible blockchain.
 *
 * @dev Usage
 * forge script ./script/RegisterExternalTokens.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force
 *
 * This scripts expect all the address json files to be available at project
 * root dir.
 */
contract RegisterExternalTokens is PantosBaseAddresses {
    AccessController accessController;
    IPantosHub public pantosHubProxy;

    function registerExternalToken(Blockchain memory otherBlockchain) private {
        string[] memory tokenSymbols = getTokenSymbols();
        for (uint256 i = 0; i < tokenSymbols.length; i++) {
            Contract contract_ = _keysToContracts[tokenSymbols[i]];
            address token = getContractAddress(contract_, false);
            string memory externalToken = getContractAddressAsString(
                contract_,
                otherBlockchain.blockchainId
            );

            PantosTypes.ExternalTokenRecord
                memory externalTokenRecord = pantosHubProxy
                    .getExternalTokenRecord(
                        token,
                        uint256(otherBlockchain.blockchainId)
                    );

            if (!externalTokenRecord.active) {
                pantosHubProxy.registerExternalToken(
                    token,
                    uint256(otherBlockchain.blockchainId),
                    externalToken
                );
                console2.log(
                    "%s externally registered on chain=%s; externalToken=%s",
                    tokenSymbols[i],
                    otherBlockchain.name,
                    externalToken
                );
            } else {
                //  Check if already registerd token matches with one in the json
                if (
                    keccak256(
                        abi.encodePacked(externalTokenRecord.externalToken)
                    ) != keccak256(abi.encodePacked(externalToken))
                ) {
                    console2.log(
                        "(Mismatch) %s already registered; chain=%s ; externalToken=%s",
                        tokenSymbols[i],
                        otherBlockchain.name,
                        externalTokenRecord.externalToken
                    );

                    pantosHubProxy.unregisterExternalToken(
                        token,
                        uint256(otherBlockchain.blockchainId)
                    );
                    console2.log(
                        "PantosHub.unregisterExternalToken(%s, %s)",
                        token,
                        uint256(otherBlockchain.blockchainId)
                    );

                    pantosHubProxy.registerExternalToken(
                        token,
                        uint256(otherBlockchain.blockchainId),
                        externalToken
                    );
                    console2.log(
                        "PantosHub.registerExternalToken(%s, %s, %s)",
                        token,
                        uint256(otherBlockchain.blockchainId),
                        externalToken
                    );
                } else {
                    console2.log(
                        "%s already registered; chain=%s ; externalToken=%s, "
                        "skipping registerExternalToken",
                        tokenSymbols[i],
                        otherBlockchain.name,
                        externalTokenRecord.externalToken
                    );
                }
            }
        }
    }

    function registerExternalTokens() private {
        for (uint256 i; i < getBlockchainsLength(); i++) {
            Blockchain memory otherBlockchain = getBlockchainById(
                BlockchainId(i)
            );

            if (
                otherBlockchain.blockchainId != thisBlockchain.blockchainId &&
                !otherBlockchain.skip
            ) {
                registerExternalToken(otherBlockchain);
            }
        }
    }

    function roleActions() public {
        readContractAddressesAllChains();

        thisBlockchain = determineBlockchain();
        pantosHubProxy = IPantosHub(
            getContractAddress(Contract.HUB_PROXY, false)
        );
        accessController = AccessController(
            getContractAddress(Contract.ACCESS_CONTROLLER, false)
        );

        vm.startBroadcast(accessController.superCriticalOps());
        registerExternalTokens();

        vm.stopBroadcast();
    }
}
