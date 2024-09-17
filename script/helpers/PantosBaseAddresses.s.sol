// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";

import {DiamondLoupeFacet} from "@diamond/facets/DiamondLoupeFacet.sol";

import {PantosForwarder} from "../../src/PantosForwarder.sol";
import {PantosToken} from "../../src/PantosToken.sol";
import {BitpandaEcosystemToken} from "../../src/BitpandaEcosystemToken.sol";
import {PantosWrapper} from "../../src/PantosWrapper.sol";
import {AccessController} from "../../src/access/AccessController.sol";
import {PantosTypes} from "../../src/interfaces/PantosTypes.sol";
import {PantosHubProxy} from "../../src/PantosHubProxy.sol";
import {PantosHubInit} from "../../src/upgradeInitializers/PantosHubInit.sol";
import {PantosRegistryFacet} from "../../src/facets/PantosRegistryFacet.sol";
import {PantosTransferFacet} from "../../src/facets/PantosTransferFacet.sol";
import {DiamondCutFacet} from "../../src/facets/DiamondCutFacet.sol";

import {PantosFacets} from "../helpers/PantosHubDeployer.s.sol";

import {PantosBaseScript} from "./PantosBaseScript.s.sol";

abstract contract PantosBaseAddresses is PantosBaseScript {
    enum Contract {
        HUB_PROXY,
        HUB_INIT,
        DIAMOND_CUT_FACET,
        DIAMOND_LOUPE_FACET,
        REGISTRY_FACET,
        TRANSFER_FACET,
        FORWARDER,
        ACCESS_CONTROLLER,
        BEST,
        PAN,
        PAN_AVAX,
        PAN_BNB,
        PAN_CELO,
        PAN_CRO,
        PAN_ETH,
        PAN_FTM,
        PAN_MATIC
    }

    struct ContractInfo {
        string key;
        address address_;
        bool isToken;
    }

    struct CurrentChainContractInfo {
        ContractInfo contractInfo;
        address newAddress;
    }

    struct ContractAddress {
        Contract contract_;
        address address_;
    }

    string private constant _addressesJsonExtention = ".json";
    string private constant _redeployedAddressesJsonExtention =
        "-REDEPLOY.json";

    string private constant _contractSerializer = "address";

    mapping(BlockchainId => mapping(Contract => ContractInfo))
        private _otherChaincontractInfo;
    mapping(Contract => CurrentChainContractInfo)
        private _currentChainContractInfo;
    mapping(string => Contract) internal _keysToContracts;

    Blockchain private thisBlockchain;

    function getContractAddress(
        Contract contract_,
        bool isRedeployed
    ) public view returns (address) {
        address contractAddress;
        if (isRedeployed) {
            contractAddress = _currentChainContractInfo[contract_].newAddress;
        } else {
            contractAddress = _currentChainContractInfo[contract_]
                .contractInfo
                .address_;
        }
        require(contractAddress != address(0), "Error: Address is zero");
        return contractAddress;
    }

    function getContractAddress(
        Contract contract_,
        BlockchainId otherBlockchainId
    ) public view returns (address) {
        require(
            otherBlockchainId != thisBlockchain.blockchainId,
            "Error: Same blockchain"
        );
        address contractAddress = _otherChaincontractInfo[otherBlockchainId][
            contract_
        ].address_;
        require(contractAddress != address(0), "Error: Address is zero");
        return contractAddress;
    }

    function getContractAddressAsString(
        Contract contract_,
        BlockchainId otherBlockchainId
    ) public view returns (string memory) {
        return vm.toString(getContractAddress(contract_, otherBlockchainId));
    }

    function readContractAddresses(Blockchain memory blockchain) public {
        string memory path = string.concat(
            blockchain.name,
            _addressesJsonExtention
        );
        string memory json = vm.readFile(path);
        string[] memory keys = vm.parseJsonKeys(json, "$");
        for (uint256 i = 0; i < keys.length; i++) {
            address address_ = vm.parseJsonAddress(
                json,
                string.concat(".", keys[i])
            );
            if (blockchain.blockchainId == thisBlockchain.blockchainId) {
                _currentChainContractInfo[_keysToContracts[keys[i]]]
                    .contractInfo
                    .address_ = address_;
            } else {
                _otherChaincontractInfo[blockchain.blockchainId][
                    _keysToContracts[keys[i]]
                ].address_ = address_;
            }
        }
    }

    function readRedeployedContractAddresses() public {
        string memory path = string.concat(
            thisBlockchain.name,
            _redeployedAddressesJsonExtention
        );
        string memory json = vm.readFile(path);
        string[] memory keys = vm.parseJsonKeys(json, "$");
        for (uint256 i = 0; i < keys.length; i++) {
            address address_ = vm.parseJsonAddress(
                json,
                string.concat(".", keys[i])
            );
            _currentChainContractInfo[_keysToContracts[keys[i]]]
                .newAddress = address_;
        }
    }

    function readContractAddressesAllChains() public {
        for (uint256 i; i < getBlockchainsLength(); i++) {
            Blockchain memory blockchain = getBlockchainById(BlockchainId(i));
            if (!blockchain.skip) {
                readContractAddresses(blockchain);
            }
        }
    }

    function exportContractAddresses(
        ContractAddress[] memory contractAddresses,
        bool isRedeployed
    ) public {
        // this makes sense only for old addresses
        string memory blockchainName = thisBlockchain.name;
        string memory addresses;
        for (uint256 i; i < contractAddresses.length - 1; i++) {
            CurrentChainContractInfo
                memory currentChainContractInfo = _currentChainContractInfo[
                    contractAddresses[i].contract_
                ];
            vm.serializeAddress(
                _contractSerializer,
                currentChainContractInfo.contractInfo.key,
                contractAddresses[i].address_
            );
        }
        CurrentChainContractInfo
            memory currentChainContractInfo_ = _currentChainContractInfo[
                contractAddresses[contractAddresses.length - 1].contract_
            ];
        addresses = vm.serializeAddress(
            _contractSerializer,
            currentChainContractInfo_.contractInfo.key,
            contractAddresses[contractAddresses.length - 1].address_
        );
        string memory jsonExtention = isRedeployed
            ? _redeployedAddressesJsonExtention
            : _addressesJsonExtention;
        vm.writeJson(addresses, string.concat(blockchainName, jsonExtention));
    }

    function overrideWithRedeployedAddresses() public {
        string memory path = string.concat(
            thisBlockchain.name,
            _addressesJsonExtention
        );
        string memory redeployPath = string.concat(
            thisBlockchain.name,
            _redeployedAddressesJsonExtention
        );
        string memory jsonRedeploy = vm.readFile(redeployPath);
        string[] memory redeployKeys = vm.parseJsonKeys(jsonRedeploy, "$");
        for (uint256 i = 0; i < redeployKeys.length; i++) {
            string memory key = string.concat(".", redeployKeys[i]);
            string memory address_ = vm.parseJsonString(jsonRedeploy, key);
            vm.writeJson(address_, path, key);
        }
    }

    function getTokenSymbols() public view returns (string[] memory) {
        uint256 length = getContractsLength();
        string[] memory tokenSymbols = new string[](length);
        uint256 count = 0;
        for (uint256 i = 0; i < length; i++) {
            CurrentChainContractInfo
                memory currentContractInfo = _currentChainContractInfo[
                    Contract(i)
                ];
            if (currentContractInfo.contractInfo.isToken) {
                tokenSymbols[count] = currentContractInfo.contractInfo.key;
                count++;
            }
        }
        // Resize the array to the actual number of token symbols
        string[] memory result = new string[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = tokenSymbols[i];
        }
        return result;
    }

    function getContractsLength() public pure returns (uint256) {
        return uint256(type(Contract).max) + 1;
    }

    constructor() {
        thisBlockchain = determineBlockchain();

        for (uint256 i; i < getBlockchainsLength(); i++) {
            Blockchain memory otherBlockchain = getBlockchainById(
                BlockchainId(i)
            );
            if (
                otherBlockchain.blockchainId != thisBlockchain.blockchainId &&
                !otherBlockchain.skip
            ) {
                BlockchainId blockchainId = BlockchainId(i);
                _otherChaincontractInfo[blockchainId][
                    Contract.HUB_PROXY
                ] = _getHubProxyContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.HUB_INIT
                ] = _getHubInitContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.DIAMOND_CUT_FACET
                ] = _getDiamondCutFacetContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.DIAMOND_LOUPE_FACET
                ] = _getDiamondLoupeFacetContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.REGISTRY_FACET
                ] = _getRegistryFacetContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.TRANSFER_FACET
                ] = _getTransferFacetContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.FORWARDER
                ] = _getForwarderContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.ACCESS_CONTROLLER
                ] = _getAccessControllerContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.BEST
                ] = _getBestContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.PAN
                ] = _getPanContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.PAN_AVAX
                ] = _getPanAVAXContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.PAN_BNB
                ] = _getPanBNBContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.PAN_CELO
                ] = _getPanCELOContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.PAN_CRO
                ] = _getPanCROContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.PAN_ETH
                ] = _getPanETHContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.PAN_FTM
                ] = _getPanFTMContractInfo();
                _otherChaincontractInfo[blockchainId][
                    Contract.PAN_MATIC
                ] = _getPanMATICContractInfo();
            }
        }
        _currentChainContractInfo[
            Contract.HUB_PROXY
        ] = CurrentChainContractInfo(_getHubProxyContractInfo(), address(0));
        _currentChainContractInfo[
            Contract.HUB_INIT
        ] = CurrentChainContractInfo(_getHubInitContractInfo(), address(0));
        _currentChainContractInfo[
            Contract.DIAMOND_CUT_FACET
        ] = CurrentChainContractInfo(
            _getDiamondCutFacetContractInfo(),
            address(0)
        );
        _currentChainContractInfo[
            Contract.DIAMOND_LOUPE_FACET
        ] = CurrentChainContractInfo(
            _getDiamondLoupeFacetContractInfo(),
            address(0)
        );
        _currentChainContractInfo[
            Contract.REGISTRY_FACET
        ] = CurrentChainContractInfo(
            _getRegistryFacetContractInfo(),
            address(0)
        );
        _currentChainContractInfo[
            Contract.TRANSFER_FACET
        ] = CurrentChainContractInfo(
            _getTransferFacetContractInfo(),
            address(0)
        );
        _currentChainContractInfo[
            Contract.FORWARDER
        ] = CurrentChainContractInfo(_getForwarderContractInfo(), address(0));
        _currentChainContractInfo[
            Contract.ACCESS_CONTROLLER
        ] = CurrentChainContractInfo(
            _getAccessControllerContractInfo(),
            address(0)
        );
        _currentChainContractInfo[Contract.BEST] = CurrentChainContractInfo(
            _getBestContractInfo(),
            address(0)
        );
        _currentChainContractInfo[Contract.PAN] = CurrentChainContractInfo(
            _getPanContractInfo(),
            address(0)
        );
        _currentChainContractInfo[
            Contract.PAN_AVAX
        ] = CurrentChainContractInfo(_getPanAVAXContractInfo(), address(0));
        _currentChainContractInfo[Contract.PAN_BNB] = CurrentChainContractInfo(
            _getPanBNBContractInfo(),
            address(0)
        );
        _currentChainContractInfo[
            Contract.PAN_CELO
        ] = CurrentChainContractInfo(_getPanCELOContractInfo(), address(0));
        _currentChainContractInfo[Contract.PAN_CRO] = CurrentChainContractInfo(
            _getPanCROContractInfo(),
            address(0)
        );
        _currentChainContractInfo[Contract.PAN_ETH] = CurrentChainContractInfo(
            _getPanETHContractInfo(),
            address(0)
        );
        _currentChainContractInfo[Contract.PAN_FTM] = CurrentChainContractInfo(
            _getPanFTMContractInfo(),
            address(0)
        );
        _currentChainContractInfo[
            Contract.PAN_MATIC
        ] = CurrentChainContractInfo(_getPanMATICContractInfo(), address(0));
        for (uint256 i; i < getContractsLength(); i++) {
            _keysToContracts[
                _currentChainContractInfo[Contract(i)].contractInfo.key
            ] = Contract(i);
        }
    }

    function _getHubProxyContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory hubProxyContractInfo = ContractInfo(
            "hub_proxy",
            address(0),
            false
        );
        return hubProxyContractInfo;
    }

    function _getHubInitContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory hubInitContractInfo = ContractInfo(
            "hub_init",
            address(0),
            false
        );
        return hubInitContractInfo;
    }

    function _getDiamondCutFacetContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory diamondCutFacetContractInfo = ContractInfo(
            "diamond_cut_facet",
            address(0),
            false
        );
        return diamondCutFacetContractInfo;
    }

    function _getDiamondLoupeFacetContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory diamondLoupeFacetContractInfo = ContractInfo(
            "diamond_loupe_facet",
            address(0),
            false
        );
        return diamondLoupeFacetContractInfo;
    }

    function _getRegistryFacetContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory registryFacetContractInfo = ContractInfo(
            "registry_facet",
            address(0),
            false
        );
        return registryFacetContractInfo;
    }

    function _getTransferFacetContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory transferFacetContractInfo = ContractInfo(
            "transfer_facet",
            address(0),
            false
        );
        return transferFacetContractInfo;
    }

    function _getForwarderContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory forwarderContractInfo = ContractInfo(
            "forwarder",
            address(0),
            false
        );
        return forwarderContractInfo;
    }

    function _getAccessControllerContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory accessControllerContractInfo = ContractInfo(
            "access_controller",
            address(0),
            false
        );
        return accessControllerContractInfo;
    }

    function _getBestContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory bestContractInfo = ContractInfo(
            "best",
            address(0),
            true
        );
        return bestContractInfo;
    }

    function _getPanContractInfo() private pure returns (ContractInfo memory) {
        ContractInfo memory panContractInfo = ContractInfo(
            "pan",
            address(0),
            true
        );
        return panContractInfo;
    }

    function _getPanAVAXContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory panAVAXContractInfo = ContractInfo(
            "panAVAX",
            address(0),
            true
        );
        return panAVAXContractInfo;
    }

    function _getPanBNBContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory panBNBContractInfo = ContractInfo(
            "panBNB",
            address(0),
            true
        );
        return panBNBContractInfo;
    }

    function _getPanCELOContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory panCELOContractInfo = ContractInfo(
            "panCELO",
            address(0),
            true
        );
        return panCELOContractInfo;
    }

    function _getPanCROContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory panCROContractInfo = ContractInfo(
            "panCRO",
            address(0),
            true
        );
        return panCROContractInfo;
    }

    function _getPanETHContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory panETHContractInfo = ContractInfo(
            "panETH",
            address(0),
            true
        );
        return panETHContractInfo;
    }

    function _getPanFTMContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory panFTMContractInfo = ContractInfo(
            "panFTM",
            address(0),
            true
        );
        return panFTMContractInfo;
    }

    function _getPanMATICContractInfo()
        private
        pure
        returns (ContractInfo memory)
    {
        ContractInfo memory panMATICContractInfo = ContractInfo(
            "panMATIC",
            address(0),
            true
        );
        return panMATICContractInfo;
    }
}
