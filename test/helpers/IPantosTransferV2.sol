// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;
pragma abicoder v2;

import {PantosTypes} from "../../src/interfaces/PantosTypes.sol";

interface IPantosTransferV2 {
    function transfer(
        PantosTypes.TransferRequest calldata request,
        bytes memory signature
    ) external returns (uint256);

    function transferFromV2(
        PantosTypes.TransferFromRequest calldata request,
        bytes memory signature,
        uint extraParam
    ) external returns (uint256);

    function transferToV2(
        PantosTypes.TransferToRequest memory request,
        address[] memory signerAddresses,
        bytes[] memory signatures,
        uint extraParam
    ) external returns (uint256);

    function isValidSenderNonce(
        address sender,
        uint256 nonce
    ) external view returns (bool);
}
