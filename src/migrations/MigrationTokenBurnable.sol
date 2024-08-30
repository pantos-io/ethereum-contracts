// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import {PantosBaseToken} from "../PantosBaseToken.sol";

/**
 * @title Pantos token
 */
contract MigrationTokenBurnable is PantosBaseToken, ERC20Burnable {
    /**
     * @dev msg.sender receives all existing tokens.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 supply_
    ) PantosBaseToken(name_, symbol_, decimals_, msg.sender) {
        ERC20._mint(msg.sender, supply_);
    }

    function setPantosForwarder(address pantosForwarder) external onlyOwner {
        _setPantosForwarder(pantosForwarder);
    }

    /**
     * @dev See {PantosBaseToken-decimals} and {ERC20-decimals}.
     */
    function decimals()
        public
        view
        override(PantosBaseToken, ERC20)
        returns (uint8)
    {
        return PantosBaseToken.decimals();
    }

    /**
     * @dev See {PantosBaseToken-symbol} and {ERC20-symbol}.
     */
    function symbol()
        public
        view
        override(PantosBaseToken, ERC20)
        returns (string memory)
    {
        return PantosBaseToken.symbol();
    }

    /**
     * @dev See {PantosBaseToken-name} and {ERC20-name}.
     */
    function name()
        public
        view
        override(PantosBaseToken, ERC20)
        returns (string memory)
    {
        return PantosBaseToken.name();
    }
}
