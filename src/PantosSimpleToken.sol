// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {PantosBaseToken} from "./PantosBaseToken.sol";

/**
 * @title Pantos-compatible simple token
 */
contract PantosSimpleToken is PantosBaseToken {
    /**
     * @dev msg.sender receives all existing tokens.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 initialSupply,
        address pantosForwarder
    ) PantosBaseToken(name_, symbol_, decimals_) {
        _mint(msg.sender, initialSupply);
        _setPantosForwarder(pantosForwarder);
    }
}
