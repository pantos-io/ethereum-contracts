// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;


import {PantosHubStorage} from "../../src/PantosHubStorage.sol";
import {PantosBaseFacet} from "../../src/facets/PantosBaseFacet.sol";

// This is just for testing purpose, new fields should be directly added to
// PantosHubStorage at the end.
struct PantosHubStorageExtended {
    PantosHubStorage pantosHubStorage;
    address newAddress;
    mapping(address => bool) newMapping;
    uint newUint;
}

contract DummyFacet {
    // Extended App Storage
    PantosHubStorageExtended internal s;

    function setNewAddress(address addr) public {
        s.newAddress = addr;
    }

    function setNewMapping(address addr) public {
        s.newMapping[addr] = true;
    }

    function setNewUint(uint num) public {
        s.newUint = num;
    }

    function getNewAddress() public view returns (address) {
        return s.newAddress;
    }

    function isNewMappingEntryForAddress(
        address addr
    ) public view returns (bool) {
        return s.newMapping[addr];
    }

    function getNewUint() public view returns (uint) {
        return s.newUint;
    }
}
