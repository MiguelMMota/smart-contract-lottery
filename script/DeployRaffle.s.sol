// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployRaffle is Script {
    Raffle raffle;

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig networkConfig = helperConfig.getConfig();

        vm.startBroadcast();
        raffle = new Raffle(
            networkConfig.subscriptionId,
            networkConfig.gasLane,
            networkConfig.interval,
            networkConfig.entranceFee,
            networkConfig.callbackGasLimit,
            networkConfig.vrfCoordinatorV2
        );
        vm.stopBroadcast();

        return (raffle, helperConfig);
    }

    function run() public {
        deployContract();
    }
}