// SPDX-License-Identifier: Apache-2.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title BEP20 token interface
 */
interface IBEP20 is IERC20 {
    /**
     * @return The token decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @return The token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @return The token name.
     */
    function name() external view returns (string memory);

    /**
     * @return The token owner.
     */
    function getOwner() external view returns (address);
}
