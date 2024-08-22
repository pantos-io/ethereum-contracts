// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {PantosCoinWrapper} from "../PantosCoinWrapper.sol";

/**
 * @title Pantos-compatible token contract that wraps the Fantom
 * blockchain network's Fantom coin
 */
contract PantosFantomWrapper is PantosCoinWrapper {
    string private constant _NAME = "Fantom (Pantos)";

    string private constant _SYMBOL = "panFTM";

    uint8 private constant _DECIMALS = 18;

    constructor(
        bool native,
        address accessControllerAddress
    )
        PantosCoinWrapper(
            _NAME,
            _SYMBOL,
            _DECIMALS,
            native,
            accessControllerAddress
        )
    {}
}
