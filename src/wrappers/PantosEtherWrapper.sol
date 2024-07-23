// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;


import {PantosCoinWrapper} from "../PantosCoinWrapper.sol";

/**
 * @title Pantos-compatible token contract that wraps the Ethereum
 * blockchain network's Ether coin
 */
contract PantosEtherWrapper is PantosCoinWrapper {
    string private constant _NAME = "Ether (Pantos)";

    string private constant _SYMBOL = "panETH";

    uint8 private constant _DECIMALS = 18;

    constructor(
        bool native
    ) PantosCoinWrapper(_NAME, _SYMBOL, _DECIMALS, native) {}
}
