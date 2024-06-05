// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;
pragma abicoder v2;

import {PantosTypes} from "../../src/interfaces/PantosTypes.sol";
import {IPantosTransferV2} from "./IPantosTransferV2.sol";
import {PantosBaseFacet} from "../../src/facets/PantosBaseFacet.sol";

contract PantosTransferV2Facet is IPantosTransferV2, PantosBaseFacet {
    function transfer(
        PantosTypes.TransferRequest calldata request,
        bytes memory signature
    ) external override returns (uint256) {
        (request);
        (signature);
        return s.nextTransferId++;
    }

    function transferFromV2(
        PantosTypes.TransferFromRequest calldata request,
        bytes memory signature,
        uint extraParam
    ) external override returns (uint256) {
        (request);
        (signature);
        (extraParam);
        return s.nextTransferId++;
    }

    function transferToV2(
        PantosTypes.TransferToRequest memory request,
        address[] memory signerAddresses,
        bytes[] memory signatures,
        uint extraParam
    ) external override returns (uint256) {
        (request);
        (signerAddresses);
        (signatures);
        (extraParam);
        return s.nextTransferId++;
    }

    function isValidSenderNonce(
        address sender,
        uint256 nonce
    ) external view override returns (bool) {
        (sender);
        (nonce);
        (s);
        return true;
    }
}
