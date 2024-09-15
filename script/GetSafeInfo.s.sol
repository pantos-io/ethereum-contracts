// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
pragma abicoder v2;

import {Script} from "forge-std/Script.sol";
import {Safe} from "@safe/Safe.sol";

contract GetSafeInfo is Script {
    function writeSafeInfo(
        address[] memory safeAddresses,
        string memory path
    ) public {
        string memory root = "root";
        string memory finalJson;

        for (uint256 i = 0; i < safeAddresses.length; i++) {
            address payable safeAddress = payable(safeAddresses[i]);
            Safe safe = Safe(safeAddress); // wrap proxy
            string memory safeJson;
            vm.serializeUintToHex(safeJson, "nonce", safe.nonce());
            vm.serializeAddress(safeJson, "owners", safe.getOwners());
            safeJson = vm.serializeUintToHex(
                safeJson,
                "threshold",
                safe.getThreshold()
            );

            // Add Safe info item to root
            finalJson = vm.serializeString(
                root,
                vm.toString(safeAddress),
                safeJson
            );
        }
        // Write the JSON data to a file
        vm.writeJson(finalJson, path);
    }

    // forge script script/GetSafeInfo.s.sol --rpc-url local-8545 --sig "run(address[])"
    // [0x7f9C8d5e3dEB92e0D23b8F7b02c273519e7F9F75] -vvvv
    function run(address[] memory safeAddresses) external {
        string memory path = "safe_owners.json";
        writeSafeInfo(safeAddresses, path);
    }
}
