// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;


import "../PantosCoinWrapper.sol";

/**
 * @title Pantos-compatible token contract that wraps the BNB Chain
 * blockchain network's BNB coin
 */
contract PantosBnbWrapper is PantosCoinWrapper {
    string private constant _NAME = "BNB (Pantos)";

    string private constant _SYMBOL = "panBNB";

    uint8 private constant _DECIMALS = 18;

    constructor(
        bool native
    ) PantosCoinWrapper(_NAME, _SYMBOL, _DECIMALS, native) {}
}
