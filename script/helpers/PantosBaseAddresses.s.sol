// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/

import {PantosToken} from "../../src/PantosToken.sol";
import {PantosTypes} from "../../src/interfaces/PantosTypes.sol";

import {PantosBaseScript} from "./PantosBaseScript.s.sol";

contract PantosBaseAddresses is PantosBaseScript {
    mapping(BlockchainId => bool) private _contractsInitializedChains;
    bool private _areRolesInitialized;
    /// @dev Mapping of BlockchainId enum to map of all contract name to addresses
    mapping(BlockchainId => mapping(string => string))
        private _contractToAddress;
    /// @dev Mapping of roles to addresses
    mapping(string => string) private _roleToAddress;
    string[] private _tokenSymbols;

    modifier onlyContractsInitializedChains(BlockchainId blockchainId) {
        require(
            _contractsInitializedChains[blockchainId],
            string(
                abi.encodePacked(
                    "PantosBaseAddresses contracts: ",
                    getBlockchainById(blockchainId).name,
                    " not initialized"
                )
            )
        );
        _;
    }

    function getContractAddress(
        Blockchain memory blockchain,
        string memory contractName
    )
        public
        view
        onlyContractsInitializedChains(blockchain.blockchainId)
        returns (string memory)
    {
        return _contractToAddress[blockchain.blockchainId][contractName];
    }

    function getRoleAddress(string memory role) public view returns (address) {
        require(
            _areRolesInitialized,
            string(abi.encodePacked("PantosBaseRoles roles: not initialized"))
        );
        return vm.parseAddress(_roleToAddress[role]);
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
            _contractToAddress[blockchain.blockchainId][keys[i]] = addr;
        }
        _contractsInitializedChains[blockchain.blockchainId] = true;
    }

    function readRolesAddresses() public {
        string memory path = string.concat(
            determineBlockchain().name,
            "_ROLES.json"
        );
        string memory json = vm.readFile(path);
        string[] memory keys = vm.parseJsonKeys(json, "$");
        for (uint256 i = 0; i < keys.length; i++) {
            string memory addr = vm.parseJsonString(
                json,
                string.concat(".", keys[i])
            );
            _roleToAddress[keys[i]] = addr;
        }
        _areRolesInitialized = true;
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
