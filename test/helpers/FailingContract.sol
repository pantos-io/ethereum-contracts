// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

contract FailingContract {
    fallback() external payable {
        require(false);
    }
}
