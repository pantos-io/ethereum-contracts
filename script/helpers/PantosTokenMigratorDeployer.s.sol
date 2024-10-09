// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {PantosTokenMigrator} from "../../src/PantosTokenMigrator.sol";

contract PantosTokenMigratorDeployer {
    function deployPantosTokenMigrator(
        address oldTokenAddress,
        address newTokenAddress
    ) public returns (PantosTokenMigrator) {
        PantosTokenMigrator pantosTokenMigrator = new PantosTokenMigrator(
            oldTokenAddress,
            newTokenAddress
        );
        return pantosTokenMigrator;
    }
}
