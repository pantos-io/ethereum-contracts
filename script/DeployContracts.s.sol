// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;
pragma abicoder v2;

import "./helpers/Constants.s.sol";
import "./helpers/PantosHubDeployer.s.sol";
import "./helpers/PantosForwarderDeployer.s.sol";
import "./helpers/PantosWrapperDeployer.s.sol";
import "./helpers/PantosTokenDeployer.s.sol";
import "./helpers/BitpandaEcosystemTokenDeployer.s.sol";

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
    ProxyAdmin public proxyAdmin;
    PantosHub public pantosHubProxy;
    PantosHub public pantosHubLogic;
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
        vm.serializeAddress(addresses, "hub_logic", address(pantosHubLogic));
        vm.serializeAddress(addresses, "hub_proxy_admin", address(proxyAdmin));
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

        (proxyAdmin, pantosHubProxy, pantosHubLogic) = deployPantosHub(
            nextTransferId
        );

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
