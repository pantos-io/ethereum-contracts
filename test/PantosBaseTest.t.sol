// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Test, Vm} from "forge-std/Test.sol";

import {PantosTypes} from "../src/interfaces/PantosTypes.sol";
import {PantosBaseToken} from "../src/PantosBaseToken.sol";
import {PantosForwarder} from "../src/PantosForwarder.sol";
import {PantosToken} from "../src/PantosToken.sol";
import {AccessController} from "../src/access/AccessController.sol";

abstract contract PantosBaseTest is Test {
    uint8 public constant MAJOR_PROTOCOL_VERSION = 0;
    uint8 public constant MINOR_PROTOCOL_VERSION = 1;
    uint8 public constant PATCH_PROTOCOL_VERSION = 0;
    bytes32 public immutable PROTOCOL_VERSION =
        bytes32(
            abi.encodePacked(
                string.concat(
                    vm.toString(MAJOR_PROTOCOL_VERSION),
                    ".",
                    vm.toString(MINOR_PROTOCOL_VERSION),
                    ".",
                    vm.toString(PATCH_PROTOCOL_VERSION)
                )
            )
        );

    uint256 public constant BLOCK_TIMESTAMP = 1000;
    uint256 public constant SERVICE_NODE_DEPOSIT_UNBONDING_PERIOD = 604800;
    uint256 public constant MINIMUM_SERVICE_NODE_DEPOSIT = 10 ** 5 * 10 ** 8;
    uint256 public constant INITIAL_SUPPLY_PAN = 1_000_000_000;
    uint256 public constant PARAMETER_UPDATE_DELAY = 3 days;
    // bitpandaEcosystemToken
    uint256 public constant INITIAL_SUPPLY_BEST = 1_000_000_000;

    // following is in sorted order, changing value will change order
    Vm.Wallet public validatorWallet = vm.createWallet("Validator");
    Vm.Wallet public validatorWallet2 = vm.createWallet("def");
    Vm.Wallet public validatorWallet3 = vm.createWallet("abc");
    Vm.Wallet public validatorWallet4 = vm.createWallet("xyz");

    address public validatorAddress = validatorWallet.addr;
    address public validatorAddress2 = validatorWallet2.addr;
    address public validatorAddress3 = validatorWallet3.addr;
    address public validatorAddress4 = validatorWallet4.addr;

    address public constant ADDRESS_ZERO = address(0);
    Vm.Wallet public testWallet = vm.createWallet("testWallet");
    Vm.Wallet public testWallet2 = vm.createWallet("testWallet2");

    address public transferSender = testWallet.addr;
    address public transferSender2 = testWallet2.addr;

    address constant TRANSFER_RECIPIENT =
        address(uint160(uint256(keccak256("TransferRecipient"))));
    address constant PANDAS_TOKEN_ADDRESS =
        address(uint160(uint256(keccak256("PandasTokenAddress"))));
    address constant PANDAS_TOKEN_ADDRESS_1 =
        address(uint160(uint256(keccak256("PandasTokenAddress1"))));
    address constant PANDAS_TOKEN_ADDRESS_2 =
        address(uint160(uint256(keccak256("PandasTokenAddress2"))));
    address constant SERVICE_NODE_ADDRESS =
        address(uint160(uint256(keccak256("ServiceNodeAddress"))));
    address constant SERVICE_NODE_ADDRESS_1 =
        address(uint160(uint256(keccak256("ServiceNodeAddress1"))));
    address constant SERVICE_NODE_ADDRESS_2 =
        address(uint160(uint256(keccak256("ServiceNodeAddress2"))));
    address constant DEPLOYER =
        address(uint160(uint256(keccak256("Deployer"))));
    address constant PAUSER = address(uint160(uint256(keccak256("Pauser"))));
    address constant MEDIUM_CRITICAL_OPS =
        address(uint160(uint256(keccak256("MediumCriticalOps"))));
    address constant SUPER_CRITICAL_OPS =
        address(uint160(uint256(keccak256("SuperCriticalOps"))));
    string constant SERVICE_NODE_URL = "service node url";
    string constant SERVICE_NODE_URL_1 = "https://servicenode1.pantos.io";
    string constant SERVICE_NODE_URL_2 = "https://servicenode2.pantos.io";
    string constant EXTERNAL_PANDAS_TOKEN_ADDRESS = "external token address";
    string constant OTHER_BLOCKCHAIN_TRANSACTION_ID =
        "other blockchain transaction ID";
    uint256 constant OTHER_BLOCKCHAIN_TRANSFER_ID = 0;
    uint256 constant NEXT_TRANSFER_ID = 0;
    uint256 constant TRANSFER_AMOUNT = 10;
    uint256 constant TRANSFER_FEE = 1;
    uint256 constant TRANSFER_NONCE = 0;
    uint256 constant TRANSFER_VALID_UNTIL = BLOCK_TIMESTAMP + 1;
    bytes32 constant PANDAS_TOKEN_FAILURE_DATA = "some failure";

    enum BlockchainId {
        TEST_CHAIN1, // 0
        TEST_CHAIN2 // 1
    }

    struct Blockchain {
        BlockchainId blockchainId;
        string name;
        uint256 feeFactor;
    }

    Blockchain public thisBlockchain =
        Blockchain(BlockchainId.TEST_CHAIN1, "TEST_CHAIN1", 800000);

    Blockchain public otherBlockchain =
        Blockchain(BlockchainId.TEST_CHAIN2, "TEST_CHAIN2", 900000);

    function deployAccessController() public returns (AccessController) {
        return
            new AccessController(
                PAUSER,
                DEPLOYER,
                MEDIUM_CRITICAL_OPS,
                SUPER_CRITICAL_OPS
            );
    }

    function deployer() public view returns (address) {
        return address(this);
    }

    // src: https://ethereum.stackexchange.com/a/83577
    function getRevertMsg(
        bytes memory _returnData
    ) public pure returns (string memory) {
        // If the _returnData length is less than 68, then the transaction
        // failed silently (without a revert message)
        if (_returnData.length < 68) return "";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    function transferRequest()
        public
        view
        returns (PantosTypes.TransferRequest memory)
    {
        return
            PantosTypes.TransferRequest(
                transferSender,
                TRANSFER_RECIPIENT,
                PANDAS_TOKEN_ADDRESS,
                TRANSFER_AMOUNT,
                SERVICE_NODE_ADDRESS,
                TRANSFER_FEE,
                TRANSFER_NONCE,
                TRANSFER_VALID_UNTIL
            );
    }

    function transferFromRequest()
        public
        view
        returns (PantosTypes.TransferFromRequest memory)
    {
        return
            PantosTypes.TransferFromRequest(
                uint256(otherBlockchain.blockchainId),
                transferSender,
                vm.toString(TRANSFER_RECIPIENT),
                PANDAS_TOKEN_ADDRESS,
                EXTERNAL_PANDAS_TOKEN_ADDRESS,
                TRANSFER_AMOUNT,
                SERVICE_NODE_ADDRESS,
                TRANSFER_FEE,
                TRANSFER_NONCE,
                TRANSFER_VALID_UNTIL
            );
    }

    function transferToRequest()
        public
        view
        returns (PantosTypes.TransferToRequest memory)
    {
        return
            PantosTypes.TransferToRequest(
                uint256(otherBlockchain.blockchainId),
                OTHER_BLOCKCHAIN_TRANSFER_ID,
                OTHER_BLOCKCHAIN_TRANSACTION_ID,
                vm.toString(transferSender),
                TRANSFER_RECIPIENT,
                EXTERNAL_PANDAS_TOKEN_ADDRESS,
                PANDAS_TOKEN_ADDRESS,
                TRANSFER_AMOUNT,
                TRANSFER_NONCE
            );
    }

    function onlyOwnerTest(
        address callee,
        bytes memory calldata_
    ) public virtual {
        vm.startPrank(address(111));
        bytes4 selector = Ownable.OwnableUnauthorizedAccount.selector;
        bytes memory revertMessage = abi.encodeWithSelector(
            selector,
            address(111)
        );
        modifierTest(callee, calldata_, revertMessage);
    }

    function onlyNativeTest(address callee, bytes memory calldata_) public {
        string memory revertMessage = "PantosWrapper: only possible on "
        "the native blockchain";
        modifierTest(callee, calldata_, revertMessage);
    }

    function onlyRoleTest(
        address callee,
        bytes memory calldata_
    ) public virtual {
        vm.startPrank(address(111));
        bytes memory revertMessage = "PantosRBAC: caller doesn't have role";
        modifierTest(callee, calldata_, revertMessage);
    }

    function whenPausedTest(
        address callee,
        bytes memory calldata_
    ) public virtual {
        bytes4 selector = Pausable.ExpectedPause.selector;
        bytes memory revertMessage = abi.encodeWithSelector(selector);
        modifierTest(callee, calldata_, revertMessage);
    }

    function whenNotPausedTest(
        address callee,
        bytes memory calldata_
    ) public virtual {
        bytes4 selector = Pausable.EnforcedPause.selector;
        bytes memory revertMessage = abi.encodeWithSelector(selector);
        modifierTest(callee, calldata_, revertMessage);
    }

    function modifierTest(
        address callee,
        bytes memory calldata_,
        string memory revertMessage
    ) public {
        modifierTest(callee, calldata_, bytes(revertMessage));
    }

    function modifierTest(
        address callee,
        bytes memory calldata_,
        bytes memory revertMessage
    ) public {
        (bool success, bytes memory response) = callee.call(calldata_);

        assertFalse(success);
        vm.expectRevert(revertMessage);
        assembly {
            revert(add(response, 32), mload(response))
        }
    }

    function assertSortedAscending(address[] memory addresses) public pure {
        if (addresses.length > 1) {
            for (uint i; i < addresses.length - 1; i++) {
                assertTrue(addresses[i] < addresses[i + 1]);
            }
        }
    }

    function mockIerc20_transferFrom(
        address tokenAddress,
        address from,
        address to,
        uint256 value,
        bool success
    ) public {
        vm.mockCall(
            tokenAddress,
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                from,
                to,
                value
            ),
            abi.encode(success)
        );
    }

    function mockIerc20_transfer(
        address tokenAddress,
        address to,
        uint256 value,
        bool success
    ) public {
        vm.mockCall(
            tokenAddress,
            abi.encodeWithSelector(IERC20.transfer.selector, to, value),
            abi.encode(success)
        );
    }

    function mockIerc20_balanceOf(
        address tokenAddress,
        address account,
        uint256 balance
    ) public {
        vm.mockCall(
            tokenAddress,
            abi.encodeWithSelector(IERC20.balanceOf.selector, account),
            abi.encode(balance)
        );
    }

    function mockIerc20_allowance(
        address tokenAddress,
        address owner,
        address spender,
        uint256 balance
    ) public {
        vm.mockCall(
            tokenAddress,
            abi.encodeWithSelector(IERC20.allowance.selector, owner, spender),
            abi.encode(balance)
        );
    }

    function mockIerc20_totalSupply(
        address tokenAddress,
        uint256 value
    ) public {
        vm.mockCall(
            tokenAddress,
            abi.encodeWithSelector(IERC20.totalSupply.selector),
            abi.encode(value)
        );
    }

    function assertEq(bytes4[] memory a, bytes4[] memory b) public pure {
        assertEq(a.length, b.length);
        for (uint i; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }

    function inArray(
        address value,
        address[] memory array
    ) internal pure returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return true;
            }
        }
        return false;
    }

    function toAddress(bytes32 value) internal pure returns (address) {
        return address(uint160(uint256(value)));
    }

    function toBool(bytes32 value) internal pure returns (bool) {
        uint8 boolValue = uint8(uint256(value));
        assert(boolValue == uint8(0) || boolValue == uint8(1));
        return boolValue == uint8(1);
    }

    // exclude this class from coverage
    function test_nothing() public {}
}
