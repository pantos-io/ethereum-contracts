// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IBEP20} from "./IBEP20.sol";

/**
 * @title Pantos token interface
 *
 * @notice The IPantosToken contract is an interfance for all Pantos token
 * contracts, containing functions which are expected by the Pantos
 * multi-blockchain system.
 */
interface IPantosToken is IERC20, IBEP20 {
    event PantosForwarderSet(address pantosForwarder);

    event PantosForwarderUnset();

    /**
     * @notice Called by the Pantos Forwarder to transfer tokens on a
     * blockchain.
     *
     * @param sender The address of the sender of the tokens.
     * @param recipient The address of the recipient of the tokens.
     * @param amount The amount of tokens to mint.
     *
     * @dev The function is only callable by a trusted Pantos Forwarder
     * contract and thefore can't be invoked by a user. The function is used
     * to transfer tokens on a blockchain between the sender and recipient.
     */
    function pantosTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) external;

    /**
     * @notice Called by the Pantos Forwarder to debit tokens on the source
     * blockchain during a cross-chain transfer.
     *
     * @param sender The address of the sender of the tokens.
     * @param amount The amount of tokens to send/burn.
     *
     * @dev The function is only callable by a trusted Pantos Forwarder
     * contract and thefore can't be invoked by a user. The function is used
     * to burn tokens on the source blockchain to initiate a cross-chain
     * transfer.
     */
    function pantosTransferFrom(address sender, uint256 amount) external;

    /**
     * @notice Called by the Pantos Forwarder to mint tokens on the destination
     * blockchain during a cross-chain transfer.
     *
     * @param recipient The address of the recipient of the tokens.
     * @param amount The amount of tokens to mint.
     *
     * @dev The function is only callable by a trusted Pantos Forwarder
     * contract and thefore can't be invoked by a user. The function is used
     * to mint tokens on the destination blockchain to finish a cross-chain
     * transfer.
     */
    function pantosTransferTo(address recipient, uint256 amount) external;

    /**
     * @notice Returns the address of the Pantos Forwarder contract.
     *
     * @return Address of the Pantos Forwarder.
     *
     */
    function getPantosForwarder() external view returns (address);
}
