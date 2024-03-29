// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

/* solhint-disable no-console*/

import "forge-std/console2.sol";

import "../src/contracts/PantosTokenMigrator.sol";

import "./PantosBaseTest.t.sol";

contract PantosTokenMigratorTest is PantosBaseTest {
    PantosTokenMigrator pantosTokenMigrator;
    address constant OLD_TOKEN_ADDRESS =
        address(uint160(uint256(keccak256("OldTokenAddress"))));
    address constant NEW_TOKEN_ADDRESS =
        address(uint160(uint256(keccak256("NewTokenAddress"))));

    function setUp() public {
        mockIerc20_totalSupply(OLD_TOKEN_ADDRESS, INITIAL_SUPPLY_PAN);
        mockIerc20_totalSupply(NEW_TOKEN_ADDRESS, INITIAL_SUPPLY_PAN);
        pantosTokenMigrator = new PantosTokenMigrator(
            OLD_TOKEN_ADDRESS,
            NEW_TOKEN_ADDRESS
        );
    }

    function test_startTokenMigration() external {
        mockIerc20_transferFrom(
            NEW_TOKEN_ADDRESS,
            deployer(),
            address(pantosTokenMigrator),
            INITIAL_SUPPLY_PAN,
            true
        );
        vm.expectEmit();
        emit PantosTokenMigrator.TokenMigrationStarted();
        vm.expectCall(
            OLD_TOKEN_ADDRESS,
            abi.encodeWithSelector(IERC20.totalSupply.selector)
        );
        vm.expectCall(
            NEW_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                deployer(),
                address(pantosTokenMigrator),
                INITIAL_SUPPLY_PAN
            )
        );

        pantosTokenMigrator.startTokenMigration();

        assertTrue(pantosTokenMigrator.isTokenMigrationStarted());
    }

    function test_startTokenMigration_WhenMigrationAlreadyStarted() external {
        startMigration();
        vm.expectRevert(
            "PantosTokenMigrator: token migration already started"
        );

        pantosTokenMigrator.startTokenMigration();
    }

    function test_migrateTokens() external {
        startMigration();
        uint256 AMOUNT_TO_MIGRATE = 1_000;
        mockIerc20_balanceOf(OLD_TOKEN_ADDRESS, deployer(), AMOUNT_TO_MIGRATE);
        mockIerc20_transferFrom(
            OLD_TOKEN_ADDRESS,
            deployer(),
            address(pantosTokenMigrator),
            AMOUNT_TO_MIGRATE,
            true
        );
        mockIerc20_transfer(
            NEW_TOKEN_ADDRESS,
            deployer(),
            AMOUNT_TO_MIGRATE,
            true
        );
        vm.expectEmit();
        emit PantosTokenMigrator.TokensMigrated(deployer(), AMOUNT_TO_MIGRATE);
        vm.expectCall(
            OLD_TOKEN_ADDRESS,
            abi.encodeWithSelector(IERC20.balanceOf.selector, deployer())
        );
        vm.expectCall(
            OLD_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                deployer(),
                address(pantosTokenMigrator),
                AMOUNT_TO_MIGRATE
            )
        );
        vm.expectCall(
            NEW_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transfer.selector,
                deployer(),
                AMOUNT_TO_MIGRATE
            )
        );

        (bool success, ) = address(pantosTokenMigrator).call(
            abi.encodeWithSelector(PantosTokenMigrator.migrateTokens.selector)
        );

        assertTrue(success);
    }

    function test_migrateTokens_WhenMigrationNotYetStarted() external {
        vm.expectRevert(
            "PantosTokenMigrator: token migration not yet started"
        );

        pantosTokenMigrator.migrateTokens();
    }

    function test_migrateTokens_WhenSenderDoesNotOwnAnyOldTokens() external {
        startMigration();
        mockIerc20_balanceOf(OLD_TOKEN_ADDRESS, deployer(), 0);
        vm.expectRevert("PantosTokenMigrator: sender does not own any tokens");

        pantosTokenMigrator.migrateTokens();
    }

    function test_getOldTokenAddress() external {
        assertEq(pantosTokenMigrator.getOldTokenAddress(), OLD_TOKEN_ADDRESS);
    }

    function test_getNewTokenAddress() external {
        assertEq(pantosTokenMigrator.getNewTokenAddress(), NEW_TOKEN_ADDRESS);
    }

    function test_isTokenMigrationStarted_AfterDeploy() external {
        assertFalse(pantosTokenMigrator.isTokenMigrationStarted());
    }

    function test_isTokenMigrationStarted_WhenStarted() external {
        startMigration();

        assertTrue(pantosTokenMigrator.isTokenMigrationStarted());
    }

    function startMigration() public {
        mockIerc20_transferFrom(
            NEW_TOKEN_ADDRESS,
            deployer(),
            address(pantosTokenMigrator),
            INITIAL_SUPPLY_PAN,
            true
        );
        pantosTokenMigrator.startTokenMigration();
    }
}
