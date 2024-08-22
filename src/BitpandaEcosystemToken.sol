// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

import {PantosRBAC} from "./access/PantosRBAC.sol";
import {PantosRoles} from "./access/PantosRoles.sol";
import {PantosBaseToken} from "./PantosBaseToken.sol";

/**
 * @title Pantos-compatible variant of the Bitpanda Ecosystem Token
 */
contract BitpandaEcosystemToken is
    PantosBaseToken,
    ERC20Burnable,
    ERC20Capped,
    ERC20Pausable,
    PantosRBAC
{
    string private constant _NAME = "Bitpanda Ecosystem Token";

    string private constant _SYMBOL = "BEST";

    uint8 private constant _DECIMALS = 8;

    uint256 private constant _MAX_SUPPLY =
        (10 ** 9) * (10 ** uint256(_DECIMALS));

    /**
     * @dev msg.sender receives all existing tokens
     */
    constructor(
        uint256 initialSupply,
        address accessControllerAddress
    )
        PantosBaseToken(_NAME, _SYMBOL, _DECIMALS)
        ERC20Capped(_MAX_SUPPLY)
        PantosRBAC(accessControllerAddress)
    {
        require(
            initialSupply <= _MAX_SUPPLY,
            "BitpandaEcosystemToken: maximum supply exceeded"
        );
        ERC20._mint(msg.sender, initialSupply);
        // Contract is paused until it is fully initialized
        _pause();
    }

    /**
     * @dev See {PantosBaseToken-onlyPantosForwarder}
     */
    modifier onlyPantosForwarder() override {
        require(
            msg.sender == getPantosForwarder(),
            "BitpandaEcosystemToken: caller is not the PantosForwarder"
        );
        _;
    }

    /**
     * @dev See {Pausable-_pause)
     */
    function pause() external whenNotPaused onlyRole(PantosRoles.PAUSER) {
        _pause();
    }

    /**
     * @dev See {Pausable-_unpause)
     */
    function unpause()
        external
        whenPaused
        onlyRole(PantosRoles.SUPER_CRITICAL_OPS)
    {
        require(
            getPantosForwarder() != address(0),
            "BitpandaEcosystemToken: PantosForwarder has not been set"
        );
        _unpause();
    }

    /**
     * @dev See {PantosBaseToken-_setPantosForwarder}
     */
    function setPantosForwarder(
        address pantosForwarder
    ) external whenPaused onlyOwner {
        _setPantosForwarder(pantosForwarder);
    }

    /**
     * @dev See {PantosBaseToken-decimals} and {ERC20-decimals}
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
     * @dev See {PantosBaseToken-symbol} and {ERC20-symbol}
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
     * @dev See {PantosBaseToken-name} and {ERC20-name}
     */
    function name()
        public
        view
        override(PantosBaseToken, ERC20)
        returns (string memory)
    {
        return PantosBaseToken.name();
    }

    /**
     * @dev See {ERC20-_update}.
     */
    function _update(
        address sender,
        address recipient,
        uint256 amount
    ) internal override(ERC20, ERC20Capped, ERC20Pausable) {
        super._update(sender, recipient, amount);
    }
}
