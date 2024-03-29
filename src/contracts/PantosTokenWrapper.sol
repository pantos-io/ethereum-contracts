// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.23;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./PantosWrapper.sol";

/**
 * @title Pantos-compatible token contract that wraps another ERC20
 * token
 *
 * @dev This token contract properly supports wrapping and unwrapping of
 * tokens on exactly one blockchain network. Thus, the wrapped token
 * address is supposed to be set to an address different from the zero
 * address on exactly one supported blockchain network.
 */
contract PantosTokenWrapper is PantosWrapper {
    address private immutable _wrappedToken;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        // slither-disable-next-line missing-zero-check
        address wrappedToken
    ) PantosWrapper(name_, symbol_, decimals_, wrappedToken != address(0)) {
        _wrappedToken = wrappedToken;
    }

    /**
     * @dev See {PantosWrapper-wrap}.
     */
    // slither-disable-next-line locked-ether
    function wrap() public payable override whenNotPaused onlyNative {
        require(
            msg.value == 0,
            "PantosTokenWrapper: no native coins accepted"
        );
        uint256 amount = IERC20(_wrappedToken).allowance(
            msg.sender,
            address(this)
        );
        require(
            IERC20(_wrappedToken).transferFrom(
                msg.sender,
                address(this),
                amount
            ),
            "PantosTokenWrapper: transfer of tokens failed"
        );
        _mint(msg.sender, amount);
    }

    /**
     * @dev See {PantosWrapper-unwrap}.
     */
    function unwrap(uint256 amount) public override whenNotPaused onlyNative {
        _burn(msg.sender, amount);
        require(
            IERC20(_wrappedToken).transfer(msg.sender, amount),
            "PantosTokenWrapper: transfer of tokens failed"
        );
    }

    /**
     * @return The address of the wrapped ERC20 token.
     */
    function getWrappedToken() public view returns (address) {
        return _wrappedToken;
    }
}
