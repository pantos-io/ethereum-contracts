// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.23;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

import "./interfaces/IPantosWrapper.sol";
import "./PantosBaseToken.sol";

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
    ERC20Pausable
{
    bool private immutable _native;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        bool native
    ) PantosBaseToken(name_, symbol_, decimals_) {
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
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    /**
     * @dev See {Pausable-_unpause).
     */
    function unpause() external whenPaused onlyOwner {
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
     * @dev See {ERC20Pausable-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override(ERC20, ERC20Pausable) {
        ERC20Pausable._beforeTokenTransfer(sender, recipient, amount);
    }
}
