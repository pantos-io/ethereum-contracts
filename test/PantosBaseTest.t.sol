// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

pragma abicoder v2;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import "../src/contracts/PantosHub.sol";
import "../src/contracts/PantosForwarder.sol";
import "../src/contracts/PantosToken.sol";

abstract contract PantosBaseTest is Test {
    uint256 public constant BLOCK_TIMESTAMP = 1000;
    uint256 public constant FEE_FACTOR_VALID_FROM_OFFSET = 600; // seconds added to current block time
    uint256 public constant FEE_FACTOR_VALID_FROM =
        BLOCK_TIMESTAMP + FEE_FACTOR_VALID_FROM_OFFSET;
    uint256 public constant SERVICE_NODE_STAKE_UNBONDING_PERIOD = 604800;
    uint256 public constant MINIMUM_TOKEN_STAKE = 10 ** 3 * 10 ** 8;
    uint256 public constant MINIMUM_SERVICE_NODE_STAKE = 10 ** 5 * 10 ** 8;
    uint256 public constant INITIAL_SUPPLY_PAN = 1_000_000_000;
    // bitpandaEcosystemToken
    uint256 public constant INITIAL_SUPPLY_BEST = (10 ** 9) * (10 ** 8);

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

    address public transferSender = testWallet.addr;

    address constant TRANSFER_RECIPIENT =
        address(uint160(uint256(keccak256("TransferRecipient"))));
    address constant PANDAS_TOKEN_ADDRESS =
        address(uint160(uint256(keccak256("PandasTokenAddress"))));
    address constant SERVICE_NODE_ADDRESS =
        address(uint160(uint256(keccak256("ServiceNodeAddress"))));
    string constant SERVICE_NODE_URL = "service node url";
    string constant EXTERNAL_PANDAS_TOKEN_ADDRESS = "external token address";
    string constant OTHER_BLOCKCHAIN_TRANSACTION_ID =
        "other blockchain transaction ID";
    uint256 constant OTHER_BLOCKCHAIN_TRANSFER_ID = 0;
    uint256 constant NEXT_TRANSFER_ID = 0;
    uint256 constant TRANSFER_AMOUNT = 10;
    uint256 constant TRANSFER_FEE = 1;
    uint256 constant TRANSFER_NONCE = 0;
    uint256 constant TRANSFER_VALID_UNTIL = BLOCK_TIMESTAMP + 1;

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

    function deployer() public view returns (address) {
        return address(this);
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

    function onlyOwnerTest(address callee, bytes memory calldata_) public {
        string memory revertMessage = "Ownable: caller is not the owner";
        vm.startPrank(address(111));
        modifierTest(callee, calldata_, revertMessage);
    }

    function onlyNativeTest(address callee, bytes memory calldata_) public {
        string memory revertMessage = "PantosWrapper: only possible on "
        "the native blockchain";
        modifierTest(callee, calldata_, revertMessage);
    }

    function whenPausedTest(address callee, bytes memory calldata_) public {
        string memory revertMessage = "Pausable: not paused";
        modifierTest(callee, calldata_, revertMessage);
    }

    function whenNotPausedTest(address callee, bytes memory calldata_) public {
        string memory revertMessage = "Pausable: paused";
        modifierTest(callee, calldata_, revertMessage);
    }

    function modifierTest(
        address callee,
        bytes memory calldata_,
        string memory revertMessage
    ) public {
        (bool success, bytes memory response) = callee.call(calldata_);

        assertFalse(success);
        vm.expectRevert(bytes(revertMessage));
        assembly {
            revert(add(response, 32), mload(response))
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

    // exclude this class from coverage
    function test_nothing() public {}
}
