// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {PantosWrapper} from "./PantosWrapper.sol";

/**
 * @title Pantos-compatible token contract that wraps a blockchain
 * network's native coin
 */
contract PantosCoinWrapper is PantosWrapper {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        bool native,
        address accessControllerAddress
    )
        PantosWrapper(
            name_,
            symbol_,
            decimals_,
            native,
            accessControllerAddress
        )
    {}

    /**
     * @dev See {PantosWrapper-wrap}.
     */
    function wrap() public payable override whenNotPaused onlyNative {
        _mint(msg.sender, msg.value);
    }

    /**
     * @dev See {PantosWrapper-unwrap}.
     */
    function unwrap(uint256 amount) public override whenNotPaused onlyNative {
        _burn(msg.sender, amount);
        // slither-disable-next-line low-level-calls
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "PantosCoinWrapper: transfer failed");
    }
}
