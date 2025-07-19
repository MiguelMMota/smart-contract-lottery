// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script, console2} from "forge-std/Script.sol";

import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

import {CodeConstants, HelperConfig} from "./HelperConfig.s.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        address vrfCoordinator = networkConfig.vrfCoordinatorV2;
        address account = networkConfig.account;
        return createSubscription(vrfCoordinator, account);
    }

    function createSubscription(
        address vrfCoordinator,
        address account
    ) public returns (uint256, address) {
        console2.log("Creating subscription on chain id: ", block.chainid);

        vm.startBroadcast(account);
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();

        console2.log("Your subscription Id is: ", subscriptionId);
        console2.log("Please update the subscriptionId in HelperConfig.s.sol");

        return (subscriptionId, vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is CodeConstants, Script {
    uint256 public constant FUND_AMOUNT = 300 ether; // 3 LINK

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getConfig();

        if (networkConfig.subscriptionId == 0) {
            CreateSubscription createSubscriptionContract = new CreateSubscription();
            (networkConfig.subscriptionId, ) = createSubscriptionContract
                .createSubscription(networkConfig.vrfCoordinatorV2, networkConfig.account);
        }

        return
            fundSubscription(
                networkConfig.vrfCoordinatorV2,
                networkConfig.subscriptionId,
                networkConfig.linkTokenAddress,
                networkConfig.account
            );
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkTokenAddress,
        address account
    ) public {
        console2.log(
            "Funding subscription ",
            subscriptionId,
            " on chain id: ",
            block.chainid
        );

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linkTokenAddress).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }

        console2.log("Funded subscription", subscriptionId);
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is CodeConstants, Script {
    uint256 public constant FUND_AMOUNT = 3 ether; // 3 LINK

    function addConsumerUsingConfig(address contractToAddTo) public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getConfig();

        return
            addConsumer(
                contractToAddTo,
                networkConfig.vrfCoordinatorV2,
                networkConfig.subscriptionId,
                networkConfig.account
            );
    }

    function addConsumer(
        address contractToAddTo,
        address vrfCoordinator,
        uint256 subscriptionId,
        address account
    ) public {
        console2.log("Adding consumer for subscription ", subscriptionId);
        console2.log("on chain id: ", block.chainid);
        console2.log(" to contract address: ", contractToAddTo);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            contractToAddTo
        );
        vm.stopBroadcast();

        console2.log("Added consumer");
    }

    function run() public {
        address mostRecentlyDeployedContractAddress = DevOpsTools
            .get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployedContractAddress);
    }
}
