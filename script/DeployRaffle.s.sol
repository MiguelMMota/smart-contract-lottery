// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {AddConsumer, CreateSubscription, FundSubscription} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    Raffle raffle;

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getConfig();

        if (networkConfig.subscriptionId == 0) {
            CreateSubscription createSubscriptionContract = new CreateSubscription();
            (networkConfig.subscriptionId, ) = createSubscriptionContract
                .createSubscription(networkConfig.vrfCoordinatorV2);

            FundSubscription fundSubscriptionContract = new FundSubscription();
            fundSubscriptionContract.fundSubscription(
                networkConfig.vrfCoordinatorV2,
                networkConfig.subscriptionId,
                networkConfig.linkTokenAddress
            );
        }

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

        AddConsumer addConsumerContract = new AddConsumer();
        address contractToAddTo = address(raffle);
        addConsumerContract.addConsumer(
            contractToAddTo,
            networkConfig.vrfCoordinatorV2,
            networkConfig.subscriptionId
        );

        return (raffle, helperConfig);
    }

    function run() public {
        deployContract();
    }
}
