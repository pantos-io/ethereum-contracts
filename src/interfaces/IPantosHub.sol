// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;


import {IERC173} from "@diamond/interfaces/IERC173.sol";

import {IPantosRegistry} from "./IPantosRegistry.sol";
import {IPantosTransfer} from "./IPantosTransfer.sol";

/**
 * @title Pantos Hub interface
 *
 * @notice The Pantos hub connects all on-chain (forwarder, tokens) and
 * off-chain (clients, service nodes, validator nodes) components of the
 * Pantos multi-blockchain system.
 *
 * @dev The interface declares all Pantos hub events and functions for token
 * owners, clients, service nodes, validator nodes, and other interested
 * external users, excluding the functions which are only allowed to be called
 * by the Pantos hub owner.
 */
interface IPantosHub is IERC173, IPantosTransfer, IPantosRegistry {}
