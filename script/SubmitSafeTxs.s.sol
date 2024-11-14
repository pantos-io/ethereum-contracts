// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
pragma abicoder v2;

/* solhint-disable no-console*/
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Safe} from "@safe/Safe.sol";
import {Enum} from "@safe/libraries/Enum.sol";

import {PantosBaseScript} from "./helpers/PantosBaseScript.s.sol";

using stdJson for string;

/**
 * @title Submit transactions to the safe
 *
 * @notice Submits the list of signed SafeTxs.
 *
 * @dev Expects a file named `flat_output.json` in project root with all the
 *  SafeTxs to be submited to Gnosis safes's `execTransaction` sequentially.
 *  Usage:
 * forge script script/SubmitSafeTxs.s.sol --account <account> \
 *     --sender <sender> --rpc-url <rpc alias> --sig "run()" -vvvv\
 *    --slow
 */
contract SubmitSafeTxs is PantosBaseScript {
    // This needs to be in alphabetical order!
    struct SafeTxDetail {
        uint256 chainId;
        bytes data;
        address from;
        bytes signatures;
        address to;
        uint256 value;
    }

    function readSafeTxDetails(
        string memory path
    ) internal view virtual returns (SafeTxDetail[] memory) {
        string memory json = vm.readFile(path);
        bytes memory transactionDetailsArray = json.parseRaw("$");
        SafeTxDetail[] memory safeTxDetails = abi.decode(
            transactionDetailsArray,
            (SafeTxDetail[])
        );
        return safeTxDetails;
    }

    function run() external {
        // read transactions
        string memory blockchainName = determineBlockchain().name;
        string memory path = string.concat(
            blockchainName,
            "_flat_output.json"
        );
        SafeTxDetail[] memory safeTxDetails = readSafeTxDetails(path);

        vm.startBroadcast();
        // Iterate through each transaction in the array and process it
        for (uint256 i = 0; i < safeTxDetails.length; i++) {
            SafeTxDetail memory safeTxDetail = safeTxDetails[i];
            console.log(safeTxDetail.to);
            console.log(safeTxDetail.value);
            console.log(safeTxDetail.chainId);
            console.logBytes(safeTxDetail.signatures);
            submit(safeTxDetail);
        }
        vm.stopBroadcast();
    }

    function submit(SafeTxDetail memory safeTxDetail) public {
        address payable safeAddress = payable(safeTxDetail.from);
        Safe safe = Safe(safeAddress); // wrap proxy

        bytes32 txHash = safe.getTransactionHash(
            safeTxDetail.to,
            safeTxDetail.value,
            safeTxDetail.data,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            safe.nonce()
        );

        console.logBytes32(txHash);

        bool success = safe.execTransaction(
            safeTxDetail.to,
            safeTxDetail.value,
            safeTxDetail.data,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            abi.encodePacked(safeTxDetail.signatures)
        );
        require(success, "Transaction failed");
    }
}
