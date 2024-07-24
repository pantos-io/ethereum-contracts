// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {PantosCoinWrapper} from "../PantosCoinWrapper.sol";

/**
 * @title Pantos-compatible token contract that wraps the Avalanche
 * blockchain network's AVAX coin
 */
contract PantosAvaxWrapper is PantosCoinWrapper {
    string private constant _NAME = "AVAX (Pantos)";

    string private constant _SYMBOL = "panAVAX";

    uint8 private constant _DECIMALS = 18;

    constructor(
        bool native
    ) PantosCoinWrapper(_NAME, _SYMBOL, _DECIMALS, native) {}
}
