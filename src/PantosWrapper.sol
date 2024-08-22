// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

import {PantosRBAC} from "./access/PantosRBAC.sol";
import {PantosRoles} from "./access/PantosRoles.sol";
import {IBEP20} from "./interfaces/IBEP20.sol";
import {IPantosWrapper} from "./interfaces/IPantosWrapper.sol";
import {PantosBaseToken} from "./PantosBaseToken.sol";

/**
 * @title Base implementation for Pantos-compatible token contracts that
 * wrap either a blockchain network's native coin or another token
 *
 * @dev This token contract properly supports wrapping and unwrapping of
 * coins on exactly one blockchain network.
 */
abstract contract PantosWrapper is
    IPantosWrapper,
    PantosBaseToken,
    ERC20Pausable,
    PantosRBAC
{
    bool private immutable _native;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        bool native,
        address accessControllerAddress
    )
        PantosBaseToken(name_, symbol_, decimals_)
        PantosRBAC(accessControllerAddress)
    {
        _native = native;
        // Contract is paused until it is fully initialized
        _pause();
    }

    /**
     * @dev See {PantosBaseToken-onlyPantosForwarder}.
     */
    modifier onlyPantosForwarder() override {
        require(
            msg.sender == getPantosForwarder(),
            "PantosWrapper: caller is not the PantosForwarder"
        );
        _;
    }

    /**
     * @dev Makes sure that the function can only be called on the native
     * blockchain.
     */
    modifier onlyNative() {
        require(
            _native,
            "PantosWrapper: only possible on the native blockchain"
        );
        _;
    }

    /**
     * @dev See {Pausable-_pause).
     */
    function pause() external whenNotPaused onlyRole(PantosRoles.PAUSER) {
        _pause();
    }

    /**
     * @dev See {Pausable-_unpause).
     */
    function unpause()
        external
        whenPaused
        onlyRole(PantosRoles.SUPER_CRITICAL_OPS)
    {
        require(
            getPantosForwarder() != address(0),
            "PantosWrapper: PantosForwarder has not been set"
        );
        _unpause();
    }

    /**
     * @dev See {PantosBaseToken-_setPantosForwarder}.
     */
    function setPantosForwarder(
        address pantosForwarder
    ) external whenPaused onlyOwner {
        _setPantosForwarder(pantosForwarder);
    }

    /**
     * @dev See {IPantosWrapper-wrap}.
     */
    function wrap() public payable virtual override;

    /**
     * @dev See {IPantosWrapper-unwrap}.
     */
    function unwrap(uint256 amount) public virtual override;

    /**
     * @dev See {IPantosWrapper-isNative}.
     */
    function isNative() public view override returns (bool) {
        return _native;
    }

    /**
     * @dev See {PantosBaseToken-decimals} and {ERC20-decimals}.
     */
    function decimals()
        public
        view
        override(PantosBaseToken, IBEP20, ERC20)
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
        override(PantosBaseToken, IBEP20, ERC20)
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
        override(PantosBaseToken, IBEP20, ERC20)
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
    ) internal override(ERC20, ERC20Pausable) {
        super._update(sender, recipient, amount);
    }
}
