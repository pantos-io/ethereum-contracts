// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {PantosRBAC} from "./access/PantosRBAC.sol";
import {PantosRoles} from "./access/PantosRoles.sol";
import {AccessController} from "./access/AccessController.sol";
import {PantosBaseToken} from "./PantosBaseToken.sol";

/**
 * @title Pantos token
 */
contract PantosToken is
    PantosBaseToken,
    ERC20Capped,
    ERC20Pausable,
    PantosRBAC
{
    string private constant _NAME = "Pantos";

    string private constant _SYMBOL = "PAN";

    uint8 private constant _DECIMALS = 8;

    uint256 private constant _MAX_SUPPLY =
        (10 ** 9) * (10 ** uint256(_DECIMALS));

    /**
     * @dev superCriticalOps receives all existing tokens
     */
    constructor(
        uint256 initialSupply,
        address accessControllerAddress
    )
        PantosBaseToken(
            _NAME,
            _SYMBOL,
            _DECIMALS,
            AccessController(accessControllerAddress).superCriticalOps()
        )
        ERC20Capped(_MAX_SUPPLY)
        PantosRBAC(accessControllerAddress)
    {
        require(
            initialSupply <= _MAX_SUPPLY,
            "PantosToken: maximum supply exceeded"
        );
        ERC20._mint(super.getOwner(), initialSupply);
        // Contract is paused until it is fully initialized
        _pause();
    }

    /**
     * @dev See {PantosBaseToken-onlyPantosForwarder}
     */
    modifier onlyPantosForwarder() override {
        require(
            msg.sender == getPantosForwarder(),
            "PantosToken: caller is not the PantosForwarder"
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
            "PantosToken: PantosForwarder has not been set"
        );
        _unpause();
    }

    /**
     *  @dev See {PantosBaseToken-_setPantosForwarder}
     */
    function setPantosForwarder(
        address pantosForwarder
    ) external whenPaused onlyOwner {
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

    /**
     * @dev Disable the transfer of ownership.
     */
    function transferOwnership(address) public view override onlyOwner {
        require(false, "PantosToken: ownership cannot be transferred");
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(PantosBaseToken) returns (bool) {
        return
            interfaceId == type(ERC20Capped).interfaceId ||
            interfaceId == type(ERC20Pausable).interfaceId ||
            super.supportsInterface(interfaceId);
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
