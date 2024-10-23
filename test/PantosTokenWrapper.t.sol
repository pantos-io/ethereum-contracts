// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
/* solhint-disable no-console*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {console2} from "forge-std/console2.sol";

import {IPantosToken} from "../src/interfaces/IPantosToken.sol";
import {IPantosWrapper} from "../src/interfaces/IPantosWrapper.sol";
import {PantosWrapper} from "../src/PantosWrapper.sol";
import {PantosTokenWrapper} from "../src/PantosTokenWrapper.sol";
import {AccessController} from "../src/access/AccessController.sol";

import {PantosBaseTest} from "./PantosBaseTest.t.sol";

contract PantosTokenWrapperTest is PantosBaseTest {
    PantosTokenWrapperHarness pantosTokenWrapper;
    string constant NAME = "test token";
    string constant SYMBOL = "TEST";
    uint8 constant DECIMALS = 18;
    uint256 constant WRAPPED_AMOUNT = 1000;
    address constant WRAPPED_TOKEN_ADDRESS =
        address(uint160(uint256(keccak256("wrappedTokenAddress"))));
    address constant PANTOS_FORWARDER_ADDRESS =
        address(uint160(uint256(keccak256("PantosForwarderAddress"))));

    AccessController public accessController;

    function setUp() public {
        accessController = deployAccessController();
        pantosTokenWrapper = new PantosTokenWrapperHarness(
            NAME,
            SYMBOL,
            DECIMALS,
            WRAPPED_TOKEN_ADDRESS,
            address(accessController)
        );
    }

    function test_pause_AfterInitialization() external {
        initializePantosTokenWrapper();

        vm.prank(PAUSER);
        pantosTokenWrapper.pause();

        assertTrue(pantosTokenWrapper.paused());
    }

    function test_pause_WhenPaused() external {
        vm.prank(SUPER_CRITICAL_OPS);
        pantosTokenWrapper.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosWrapper.pause.selector
        );

        whenNotPausedTest(address(pantosTokenWrapper), calldata_);
    }

    function test_pause_ByNonPauser() external {
        initializePantosTokenWrapper();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosWrapper.pause.selector
        );

        onlyRoleTest(address(pantosTokenWrapper), calldata_);
    }

    function test_unpause_AfterDeploy() external {
        initializePantosTokenWrapper();

        assertFalse(pantosTokenWrapper.paused());
    }

    function test_unpause_WhenNotpaused() external {
        initializePantosTokenWrapper();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosWrapper.unpause.selector
        );

        whenPausedTest(address(pantosTokenWrapper), calldata_);
    }

    function test_unpause_ByNonSuperCriticalOps() external {
        vm.prank(SUPER_CRITICAL_OPS);
        pantosTokenWrapper.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosWrapper.unpause.selector
        );

        onlyRoleTest(address(pantosTokenWrapper), calldata_);
    }

    function test_unpause_WithNoForwarderSet() external {
        vm.expectRevert(
            abi.encodePacked("PantosWrapper: PantosForwarder has not been set")
        );

        vm.prank(SUPER_CRITICAL_OPS);
        pantosTokenWrapper.unpause();
    }

    function test_setPantosForwarder() external {
        initializePantosTokenWrapper();

        assertEq(
            pantosTokenWrapper.getPantosForwarder(),
            PANTOS_FORWARDER_ADDRESS
        );
    }

    function test_setPantosForwarder_WhenNotpaused() external {
        initializePantosTokenWrapper();
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosWrapper.setPantosForwarder.selector,
            PANTOS_FORWARDER_ADDRESS
        );

        whenPausedTest(address(pantosTokenWrapper), calldata_);
    }

    function test_setPantosForwarder_ByNonOwner() external {
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosWrapper.setPantosForwarder.selector,
            PANTOS_FORWARDER_ADDRESS
        );

        onlyOwnerTest(address(pantosTokenWrapper), calldata_);
    }

    function test_wrap() external {
        initializePantosTokenWrapper();
        mockIerc20_allowance(
            WRAPPED_TOKEN_ADDRESS,
            deployer(),
            address(pantosTokenWrapper),
            WRAPPED_AMOUNT
        );
        mockIerc20_transferFrom(
            WRAPPED_TOKEN_ADDRESS,
            deployer(),
            address(pantosTokenWrapper),
            WRAPPED_AMOUNT,
            true
        );
        vm.expectCall(
            WRAPPED_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.allowance.selector,
                deployer(),
                address(pantosTokenWrapper)
            )
        );
        vm.expectCall(
            WRAPPED_TOKEN_ADDRESS,
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                deployer(),
                address(pantosTokenWrapper)
            )
        );
        vm.expectEmit();
        emit IERC20.Transfer(address(0), deployer(), WRAPPED_AMOUNT);

        pantosTokenWrapper.wrap();

        assertEq(pantosTokenWrapper.balanceOf(deployer()), WRAPPED_AMOUNT);
    }

    function test_wrap_WhenPaused() external {
        vm.prank(SUPER_CRITICAL_OPS);
        pantosTokenWrapper.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosWrapper.pause.selector
        );

        whenNotPausedTest(address(pantosTokenWrapper), calldata_);
    }

    function test_wrap_WhenNotNative() external {
        PantosTokenWrapper pantosTokenWrapper_ = new PantosTokenWrapper(
            NAME,
            SYMBOL,
            DECIMALS,
            ADDRESS_ZERO,
            address(accessController)
        );
        vm.startPrank(SUPER_CRITICAL_OPS);
        pantosTokenWrapper_.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        pantosTokenWrapper_.unpause();
        vm.stopPrank();

        bytes memory calldata_ = abi.encodeWithSelector(
            PantosTokenWrapper.wrap.selector
        );

        onlyNativeTest(address(pantosTokenWrapper_), calldata_);
    }

    function test_wrap_WithNativeCoins() external {
        initializePantosTokenWrapper();
        vm.expectRevert("PantosTokenWrapper: no native coins accepted");

        pantosTokenWrapper.wrap{value: 1}();
    }

    function test_unwrap() external {
        wrap(WRAPPED_AMOUNT);
        mockIerc20_transfer(
            WRAPPED_TOKEN_ADDRESS,
            deployer(),
            WRAPPED_AMOUNT,
            true
        );
        vm.expectEmit();
        emit IERC20.Transfer(deployer(), ADDRESS_ZERO, WRAPPED_AMOUNT);

        pantosTokenWrapper.unwrap(WRAPPED_AMOUNT);

        assertEq(pantosTokenWrapper.balanceOf(deployer()), 0);
    }

    function test_unwrap_WhenPaused() external {
        vm.prank(SUPER_CRITICAL_OPS);
        pantosTokenWrapper.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        bytes memory calldata_ = abi.encodeWithSelector(
            PantosWrapper.unwrap.selector,
            WRAPPED_AMOUNT
        );

        whenNotPausedTest(address(pantosTokenWrapper), calldata_);
    }

    function test_unwrap_WhenNotNative() external {
        PantosTokenWrapper pantosTokenWrapper_ = new PantosTokenWrapper(
            NAME,
            SYMBOL,
            DECIMALS,
            ADDRESS_ZERO,
            address(accessController)
        );

        vm.startPrank(SUPER_CRITICAL_OPS);
        pantosTokenWrapper_.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        pantosTokenWrapper_.unpause();
        vm.stopPrank();

        bytes memory calldata_ = abi.encodeWithSelector(
            PantosTokenWrapper.unwrap.selector,
            WRAPPED_AMOUNT
        );

        onlyNativeTest(address(pantosTokenWrapper_), calldata_);
    }

    function test_getWrappedToken() external view {
        assertEq(pantosTokenWrapper.getWrappedToken(), WRAPPED_TOKEN_ADDRESS);
    }

    function test_isNative_WhenNative() external view {
        assertEq(pantosTokenWrapper.isNative(), true);
    }

    function test_isNative_WhenNotNative() external {
        PantosTokenWrapper pantosTokenWrapper_ = new PantosTokenWrapper(
            NAME,
            SYMBOL,
            DECIMALS,
            ADDRESS_ZERO,
            address(accessController)
        );

        assertEq(pantosTokenWrapper_.isNative(), false);
    }

    function test_decimals() external view {
        assertEq(DECIMALS, pantosTokenWrapper.decimals());
    }

    function test_symbol() external view {
        assertEq(SYMBOL, pantosTokenWrapper.symbol());
    }

    function test_name() external view {
        assertEq(NAME, pantosTokenWrapper.name());
    }

    function test_renounceOwnership() external {
        vm.prank(SUPER_CRITICAL_OPS);
        pantosTokenWrapper.renounceOwnership();

        assertEq(pantosTokenWrapper.getOwner(), address(0));
    }

    function test_transferOwnership() external {
        vm.expectRevert(
            abi.encodePacked("PantosWrapper: ownership cannot be transferred")
        );

        vm.prank(SUPER_CRITICAL_OPS);
        pantosTokenWrapper.transferOwnership(address(1));

        assertEq(pantosTokenWrapper.getOwner(), SUPER_CRITICAL_OPS);
    }

    function test_update_WhenNotPaused() external {
        initializePantosTokenWrapper();

        bytes memory calldata_ = abi.encodeWithSelector(
            PantosTokenWrapperHarness.exposed_update.selector,
            ADDRESS_ZERO,
            ADDRESS_ZERO,
            0
        );
        (bool success, ) = address(pantosTokenWrapper).call(calldata_);

        assertTrue(success);
    }

    function test_update_WhenPaused() external {
        bytes memory revertMessage = abi.encodeWithSelector(
            Pausable.EnforcedPause.selector
        );
        vm.expectRevert(revertMessage);

        pantosTokenWrapper.exposed_update(ADDRESS_ZERO, ADDRESS_ZERO, 0);
    }

    function test_supportsInterface() external virtual {
        initializePantosTokenWrapper();
        bytes4[4] memory interfaceIds = [
            bytes4(0x01ffc9a7),
            type(IPantosWrapper).interfaceId,
            type(ERC20).interfaceId,
            type(ERC20Pausable).interfaceId
        ];
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            bytes4 interfaceId = interfaceIds[i];
            assert(pantosTokenWrapper.supportsInterface(interfaceId));
        }

        assert(!pantosTokenWrapper.supportsInterface(0xffffffff));
    }

    function wrap(uint256 amount) public {
        initializePantosTokenWrapper();
        mockIerc20_allowance(
            WRAPPED_TOKEN_ADDRESS,
            deployer(),
            address(pantosTokenWrapper),
            amount
        );
        mockIerc20_transferFrom(
            WRAPPED_TOKEN_ADDRESS,
            deployer(),
            address(pantosTokenWrapper),
            amount,
            true
        );

        pantosTokenWrapper.wrap();
    }

    function initializePantosTokenWrapper() public {
        vm.startPrank(SUPER_CRITICAL_OPS);
        pantosTokenWrapper.setPantosForwarder(PANTOS_FORWARDER_ADDRESS);
        pantosTokenWrapper.unpause();
        vm.stopPrank();
    }
}

contract PantosTokenWrapperHarness is PantosTokenWrapper {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address wrappedToken,
        address accessController
    )
        PantosTokenWrapper(
            name,
            symbol,
            decimals,
            wrappedToken,
            accessController
        )
    {}

    function exposed_update(
        address from,
        address to,
        uint256 amount
    ) external {
        _update(from, to, amount);
    }
}
