// SPDX-License-Identifier: GPL-3.0
// slither-disable-next-line solc-version
pragma solidity 0.8.26;

/**
 * @notice Abstract class for all Pantos contracts which implement RBAC 
 * (Role-Based Access Control), based on the Pantos roles. The roles
 * are embeded in the compiled contract and are immutable.

 * @dev The contract can be used by logic contracts (such as diamond facets)
 * or smart contracts which hold their own storage. It should not have any 
 * public methods, so it does not colide with other facets. 
 */
abstract contract PantosRBAC {
    address private immutable _DEPLOYER;
    address private immutable _PAUSER;
    address private immutable _MEDIUM_CRITICAL_OPS;
    address private immutable _SUPER_CRITICAL_OPS;

    /**
     * @notice Sets the RBAC rols.
     *
     * @param _deployer The address of the deployer role.
     * @param _pauser The address of the pauser role.
     * @param _mediumCriticalOps The address of the medium critical ops role.
     * @param _superCriticalOps The address of the super critical ops role.
     */
    constructor(
        address _deployer,
        address _pauser,
        address _mediumCriticalOps,
        address _superCriticalOps
    ) {
        _DEPLOYER = _deployer;
        _PAUSER = _pauser;
        _MEDIUM_CRITICAL_OPS = _mediumCriticalOps;
        _SUPER_CRITICAL_OPS = _superCriticalOps;
    }

    function _enforceIsDeployer() internal view {
        require(
            msg.sender == _DEPLOYER,
            "PantosRBAC: caller is not the deployer"
        );
    }

    function _enforceIsPauser() internal view {
        require(msg.sender == _PAUSER, "PantosRBAC: caller is not the pauser");
    }

    function _enforceIsMediumCriticalOps() internal view {
        require(
            msg.sender == _MEDIUM_CRITICAL_OPS,
            "PantosRBAC: caller is not the medium critical ops"
        );
    }

    function _enforceIsSuperCriticalOps() internal view {
        require(
            msg.sender == _SUPER_CRITICAL_OPS,
            "PantosRBAC: caller is not the super critical ops"
        );
    }

    /**
     * @notice Modifier which makes sure that only a transaction from the
     * deployer is allowed.
     */
    modifier onlyDeployer() {
        _enforceIsDeployer();
        _;
    }

    /**
     * @notice Modifier which makes sure that only a transaction from the
     * pauser is allowed.
     */
    modifier onlyPauser() {
        _enforceIsPauser();
        _;
    }

    /**
     * @notice Modifier which makes sure that only a transaction from the
     * medium critical ops is allowed.
     */
    modifier onlyMediumCriticalOps() {
        _enforceIsMediumCriticalOps();
        _;
    }

    /**
     * @notice Modifier which makes sure that only a transaction from the
     * super critical ops is allowed.
     */
    modifier onlySuperCriticalOps() {
        _enforceIsSuperCriticalOps();
        _;
    }
}
