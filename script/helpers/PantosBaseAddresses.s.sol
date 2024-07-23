// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;


/* solhint-disable no-console*/

import {PantosToken} from "../../src/PantosToken.sol";
import {PantosTypes} from "../../src/interfaces/PantosTypes.sol";

import {PantosBaseScript} from "./PantosBaseScript.s.sol";

contract PantosBaseAddresses is PantosBaseScript {
    mapping(BlockchainId => bool) public initializedChains;
    /// @dev Mapping of BlockchainId enum to map of all contract name to addresses
    mapping(BlockchainId => mapping(string => string)) private _addresses;
    string[] private _tokenSymbols;

    modifier onlyInitializedChains(BlockchainId blockchainId) {
        require(
            initializedChains[blockchainId],
            string(
                abi.encodePacked(
                    "PantosForwarderRedeployer: ",
                    getBlockchainById(blockchainId).name,
                    " not initialized"
                )
            )
        );
        _;
    }

    function getContractAddress(
        Blockchain memory blockchain,
        string memory tokenSymbol
    )
        public
        view
        onlyInitializedChains(blockchain.blockchainId)
        returns (string memory)
    {
        return _addresses[blockchain.blockchainId][tokenSymbol];
    }

    function readContractAddresses(Blockchain memory blockchain) public {
        string memory path = string.concat(blockchain.name, ".json");
        string memory json = vm.readFile(path);
        string[] memory keys = vm.parseJsonKeys(json, "$");
        for (uint256 i = 0; i < keys.length; i++) {
            string memory addr = vm.parseJsonString(
                json,
                string.concat(".", keys[i])
            );
            _addresses[blockchain.blockchainId][keys[i]] = addr;
        }
        initializedChains[blockchain.blockchainId] = true;
    }

    function readContractAddressesAllChains() public {
        for (uint256 i; i < getBlockchainsLength(); i++) {
            Blockchain memory blockchain = getBlockchainById(BlockchainId(i));
            if (!blockchain.skip) {
                readContractAddresses(blockchain);
            }
        }
    }

    function getTokenSymbols() public view returns (string[] memory) {
        return _tokenSymbols;
    }

    constructor() PantosBaseScript() {
        // All active tokens symbol including best and pan
        _tokenSymbols = [
            "best",
            "pan",
            "panAVAX",
            "panBNB",
            "panCELO",
            "panCRO",
            "panETH",
            "panFTM",
            "panMATIC"
        ];
    }
}
