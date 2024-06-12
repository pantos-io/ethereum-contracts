// SPDX-License-Identifier: MIT
// slither-disable-next-line solc-version
pragma solidity 0.8.26;
pragma abicoder v2;

import {PantosHubStorageExtended} from "./DummyFacet.sol";

contract PantosHubReinit {
    PantosHubStorageExtended internal ps;

    struct Args {
        address newAddress;
        address newMappingAddress;
        uint newUint;
    }

    function init(Args memory args) external {
        // safety check to ensure, reinit is only called once
        require(
            ps.pantosHubStorage.initialized == 1,
            "PantosHubRenit: contract is already initialized"
        );
        ps.pantosHubStorage.initialized = 2;

        // initialising PantosHubStorage
        ps.newAddress = args.newAddress;
        ps.newMapping[args.newMappingAddress] = true;
        ps.newUint = args.newUint;
    }
}
