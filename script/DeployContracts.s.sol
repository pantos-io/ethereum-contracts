// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
pragma abicoder v2;

import {IPantosHub} from "../src/interfaces/IPantosHub.sol";
import {PantosForwarder} from "../src/PantosForwarder.sol";
import {PantosToken} from "../src/PantosToken.sol";
import {BitpandaEcosystemToken} from "../src/BitpandaEcosystemToken.sol";

import {Constants} from "./helpers/Constants.s.sol";
import {PantosHubDeployer, DeployedFacets} from "./helpers/PantosHubDeployer.s.sol";
import {PantosForwarderDeployer} from "./helpers/PantosForwarderDeployer.s.sol";
import {PantosWrapperDeployer} from "./helpers/PantosWrapperDeployer.s.sol";
import {PantosTokenDeployer} from "./helpers/PantosTokenDeployer.s.sol";
import {BitpandaEcosystemTokenDeployer} from "./helpers/BitpandaEcosystemTokenDeployer.s.sol";

/**
 * @title DeployContracts
 *
 * @notice Deploy and initialize all the Pantos smart contracts on an
 * Ethereum-compatible single blockchain.
 *
 * @dev Usage
 * forge script ./script/DeployContracts.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force \
 *     --sig "run(address,uint256,uint256,uint256)" <validator> <panSupply> \
 *     <bestSupply> <nextTransferId>
 */
contract DeployContracts is
    PantosHubDeployer,
    PantosForwarderDeployer,
    PantosWrapperDeployer,
    PantosTokenDeployer,
    BitpandaEcosystemTokenDeployer
{
    IPantosHub public pantosHubProxy;
    PantosForwarder public pantosForwarder;
    PantosToken public pantosToken;
    BitpandaEcosystemToken public bitpandaEcosystemToken;

    function approveAmountAtPantosToken() public {
        // Approve amount at PantosToken
        // Approve amount for all the wrapers + BEST tokens
        uint256 amount = (pantosWrappers.length + 1) *
            Constants.MINIMUM_TOKEN_STAKE;
        pantosToken.approve(address(pantosHubProxy), amount);
    }

    function exportContractAddresses() public {
        string memory blockchainName = determineBlockchain().name;
        string memory addresses;
        for (uint256 i; i < pantosWrappers.length; i++) {
            vm.serializeAddress(
                addresses,
                pantosWrappers[i].symbol(),
                address(pantosWrappers[i])
            );
        }

        vm.serializeAddress(addresses, "hub_proxy", address(pantosHubProxy));
        vm.serializeAddress(addresses, "forwarder", address(pantosForwarder));
        vm.serializeAddress(addresses, "pan", address(pantosToken));
        addresses = vm.serializeAddress(
            addresses,
            "best",
            address(bitpandaEcosystemToken)
        );
        vm.writeJson(addresses, string.concat(blockchainName, ".json"));
    }

    function run(
        address validator,
        uint256 panSupply,
        uint256 bestSupply,
        uint256 nextTransferId
    ) public {
        vm.startBroadcast();

        (pantosHubProxy, ) = deployPantosHub(nextTransferId);

        pantosForwarder = deployPantosForwarder();
        pantosToken = deployPantosToken(panSupply);
        bitpandaEcosystemToken = deployBitpandaEcosystemToken(bestSupply);

        deployCoinWrappers();

        initializePantosHub(
            pantosHubProxy,
            pantosForwarder,
            pantosToken,
            // PAN-1721: primary validator node address
            validator
        );

        // PAN-1721: all validator node addresses
        address[] memory validatorNodeAddresses = new address[](1);
        validatorNodeAddresses[0] = validator;
        initializePantosForwarder(
            pantosForwarder,
            pantosHubProxy,
            pantosToken,
            validatorNodeAddresses
        );

        // approve needs to be done before token registration
        approveAmountAtPantosToken();

        initializePantosToken(pantosToken, pantosForwarder);
        initializeBitpandaEcosystemToken(
            bitpandaEcosystemToken,
            pantosHubProxy,
            pantosForwarder
        );
        initializePantosWrappers(pantosHubProxy, pantosForwarder);

        vm.stopBroadcast();

        exportContractAddresses();
    }
}
