// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";

import {PantosTypes} from "../../../src/interfaces/PantosTypes.sol";

contract UpdateBase is Script {
    enum UpdateState {
        INITIATE,
        EXECUTE
    }

    function isInitiateOrExecute(
        PantosTypes.UpdatableUint256 memory updatableUint256,
        uint256 newValue
    ) internal returns (UpdateState) {
        uint256 currentTime = vm.unixTime() / 1000;
        uint256 updateTime = updatableUint256.updateTime;
        bool currentUpToDate = updatableUint256.currentValue == newValue;
        bool pendingUpToDate = updatableUint256.pendingValue == newValue;
        bool initiateUpdate = (!currentUpToDate && !pendingUpToDate) ||
            (!pendingUpToDate && updateTime > 0);
        bool executeUpdate = !currentUpToDate &&
            pendingUpToDate &&
            updateTime > 0 &&
            currentTime >= updateTime;
        assert(!(initiateUpdate && executeUpdate));

        if (initiateUpdate) {
            return UpdateState.INITIATE;
        } else if (executeUpdate) {
            return UpdateState.EXECUTE;
        } else {
            revert("UpdateBase: Invalid update state");
        }
    }
}
