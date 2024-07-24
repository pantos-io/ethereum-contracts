// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

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
    Blockchain public thisBlockchain;
    IPantosHub public pantosHubProxy;

    function registerExternalToken(Blockchain memory otherBlockchain) public {
        string[] memory tokenSymbols = getTokenSymbols();
        for (uint256 i = 0; i < tokenSymbols.length; i++) {
            string memory tokenSymbol = tokenSymbols[i];
            address token = vm.parseAddress(
                getContractAddress(thisBlockchain, tokenSymbol)
            );
            string memory externalToken = getContractAddress(
                otherBlockchain,
                tokenSymbol
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
                    tokenSymbol,
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
                        tokenSymbol,
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
                        tokenSymbol,
                        otherBlockchain.name,
                        externalTokenRecord.externalToken
                    );
                }
            }
        }
    }

    function registerExternalTokens() public {
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

    function run() public {
        readContractAddressesAllChains();

        vm.startBroadcast();

        thisBlockchain = determineBlockchain();
        pantosHubProxy = IPantosHub(
            vm.parseAddress(getContractAddress(thisBlockchain, "hub_proxy"))
        );

        registerExternalTokens();

        vm.stopBroadcast();
    }
}
