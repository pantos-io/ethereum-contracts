// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
pragma abicoder v2;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {Safe} from "@safe/Safe.sol";
import {SafeProxyFactory} from "@safe/proxies/SafeProxyFactory.sol";
import {SafeProxy} from "@safe/proxies/SafeProxy.sol";

import {SafeAddresses} from "./helpers/SafeAddresses.s.sol";

/**
 * @title Deploy safe contracts
 *
 * @notice Deploy the gnosis safe contracts which act as the multi-sig
 * Pantos roles.
 *
 * @dev Usage
 * Deploy by any gas paying account:
 * forge script ./script/DeploySafe.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --slow --force --sig \
 *     "deploySafes(address[], uint256, address[], uint256, address[], \
 *     uint256, address[], uint256)" \
 *     <pauserAddresses> <pauserSafeThreshold> \
 *     <deployerAddresses> <deployerSafeThreshold> \
 *     <mediumCriticalOpsAddresses> <mediumCriticalOpsSafeThreshold> \
 *     <superCriticalOpsAddresses> <superCriticalOpsSafeThreshold>
 *
 */
contract DeploySafe is SafeAddresses {
    uint256 private constant PAUSER_SALT = 1;
    uint256 private constant DEPLOYER_SALT = 2;
    uint256 private constant MEDIUM_CRITICAL_OPS_SALT = 3;
    uint256 private constant SUPER_CRITICAL_OPS_SALT = 4;

    function deploySafeInfrastracture()
        private
        returns (Safe, SafeProxyFactory)
    {
        Safe safeMasterCopy = new Safe();
        console.log("Safe Master Copy deployed at:", address(safeMasterCopy));
        SafeProxyFactory proxyFactory = new SafeProxyFactory();
        console.log("Proxy Factory deployed at:", address(proxyFactory));

        return (safeMasterCopy, proxyFactory);
    }

    function deploySafe(
        SafeProxyFactory proxyFactory,
        Safe safeMasterCopy,
        uint256 saltNonce,
        address[] memory owners,
        uint256 threshold
    ) private returns (Safe) {
        bytes memory setupData = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners,
            threshold,
            address(0),
            "",
            address(0),
            address(0),
            0,
            address(0)
        );
        SafeProxy safeProxy = proxyFactory.createChainSpecificProxyWithNonce(
            address(safeMasterCopy),
            setupData,
            saltNonce
        );
        return Safe(payable(address(safeProxy)));
    }

    function deploySafes(
        address[] memory pauserAddresses,
        uint256 pauserSafeThreshold,
        address[] memory deployerAddresses,
        uint256 deployerSafeThreshold,
        address[] memory mediumCriticalOpsAddresses,
        uint256 mediumCriticalOpsSafeThreshold,
        address[] memory superCriticalOpsAddresses,
        uint256 superCriticalOpsSafeThreshold
    ) external {
        vm.startBroadcast();
        (
            Safe safeMasterCopy,
            SafeProxyFactory proxyFactory
        ) = deploySafeInfrastracture();
        Safe pauserSafe = deploySafe(
            proxyFactory,
            safeMasterCopy,
            PAUSER_SALT,
            pauserAddresses,
            pauserSafeThreshold
        );
        console.log("Pauser Safe deployed at:", address(pauserSafe));
        Safe deployerSafe = deploySafe(
            proxyFactory,
            safeMasterCopy,
            DEPLOYER_SALT,
            deployerAddresses,
            deployerSafeThreshold
        );
        console.log("Deployer Safe deployed at:", address(deployerSafe));
        Safe mediumCriticalOpsSafe = deploySafe(
            proxyFactory,
            safeMasterCopy,
            MEDIUM_CRITICAL_OPS_SALT,
            mediumCriticalOpsAddresses,
            mediumCriticalOpsSafeThreshold
        );
        console.log(
            "Medium Critical Ops Safe deployed at:",
            address(mediumCriticalOpsSafe)
        );
        Safe superCriticalOpsSafe = deploySafe(
            proxyFactory,
            safeMasterCopy,
            SUPER_CRITICAL_OPS_SALT,
            superCriticalOpsAddresses,
            superCriticalOpsSafeThreshold
        );
        console.log(
            "Super Critical Ops Safe deployed at:",
            address(superCriticalOpsSafe)
        );
        address[] memory safeAddresses = new address[](4);
        safeAddresses[0] = address(pauserSafe);
        safeAddresses[1] = address(deployerSafe);
        safeAddresses[2] = address(mediumCriticalOpsSafe);
        safeAddresses[3] = address(superCriticalOpsSafe);

        vm.stopBroadcast();

        writeSafeInfo(safeAddresses);
        exportPantosRolesAddresses(
            address(pauserSafe),
            address(deployerSafe),
            address(mediumCriticalOpsSafe),
            address(superCriticalOpsSafe)
        );
    }
}
