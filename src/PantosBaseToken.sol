// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;


import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IBEP20} from "./interfaces/IBEP20.sol";
import {IPantosToken} from "./interfaces/IPantosToken.sol";

/**
 * @title Pantos base token
 *
 * @notice The PantosBaseToken contract is an abstract contract which implements
 * the IPantosToken interface. It is meant to be used as a base contract for
 * all Pantos-compatible token contracts.
 */
abstract contract PantosBaseToken is IPantosToken, ERC20, Ownable {
    uint8 private immutable _decimals;

    address private _pantosForwarder;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        _decimals = decimals_;
    }

    /**
     * @notice Modifier to make a function callable only by the Pantos Forwarder
     */
    modifier onlyPantosForwarder() virtual {
        require(
            _pantosForwarder != address(0),
            "PantosBaseToken: PantosForwarder has not been set"
        );
        require(
            msg.sender == _pantosForwarder,
            "PantosBaseToken: caller is not the PantosForwarder"
        );
        _;
    }

    /**
     * @dev See {IPantosToken-pantosTransfer}
     */
    function pantosTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override onlyPantosForwarder {
        _transfer(sender, recipient, amount);
    }

    /**
     * @dev See {IPantosToken-pantosTransferFrom}
     */
    function pantosTransferFrom(
        address sender,
        uint256 amount
    ) public virtual override onlyPantosForwarder {
        _burn(sender, amount);
    }

    /**
     * @dev See {IPantosToken-pantosTransferTo}
     */
    function pantosTransferTo(
        address recipient,
        uint256 amount
    ) public virtual override onlyPantosForwarder {
        _mint(recipient, amount);
    }

    /**
     * @dev See {IBEP20-decimals} and {ERC20-decimals}
     */
    function decimals()
        public
        view
        virtual
        override(IBEP20, ERC20)
        returns (uint8)
    {
        return _decimals;
    }

    /**
     * @dev See {IBEP20-symbol} and {ERC20-symbol}
     */
    function symbol()
        public
        view
        virtual
        override(IBEP20, ERC20)
        returns (string memory)
    {
        return ERC20.symbol();
    }

    /**
     * @dev See {IBEP20-name} and {ERC20-name}
     */
    function name()
        public
        view
        virtual
        override(IBEP20, ERC20)
        returns (string memory)
    {
        return ERC20.name();
    }

    /**
     * @dev See {IBEP20-getOwner} and {Ownable-owner}
     */
    function getOwner() public view virtual override returns (address) {
        return owner();
    }

    /**
     * @dev See {IPantosToken-getPantosForwarder}
     */
    function getPantosForwarder()
        public
        view
        virtual
        override
        returns (address)
    {
        return _pantosForwarder;
    }

    function _setPantosForwarder(
        address pantosForwarder
    ) internal virtual onlyOwner {
        require(
            pantosForwarder != address(0),
            "PantosBaseToken: PantosForwarder must not be the zero account"
        );
        _pantosForwarder = pantosForwarder;
        emit PantosForwarderSet(pantosForwarder);
    }

    // slither-disable-next-line dead-code
    function _unsetPantosForwarder() internal virtual onlyOwner {
        _pantosForwarder = address(0);
        emit PantosForwarderUnset();
    }
}
