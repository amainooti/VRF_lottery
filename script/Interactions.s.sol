// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperconfig = new HelperConfig();

        (,, address vrfCoordinator,,,, address link) = helperconfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint64) {
        vm.startBroadcast();
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();

        console.log("Your Sub ID is: ", subId);
        console.log("Please update subscription ID");

        vm.stopBroadcast();
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperconfig = new HelperConfig();

        (,, address vrfCoordinator,,, uint64 subId, address link) = helperconfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subId, link);
    }

    function fundSubscription(address vrfCoordinator, uint64 subId, address link) public {
        console.log("Your Sub ID is: ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On chainID: ", block.chainid);

        if (block.chainid == 31337) {
            vm.startBroadcast();
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(address raffle, address vrfCoordinator, uint64 subId) public {
        console.log("Your Sub ID is: ", raffle);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On chainID: ", block.chainid);

        vm.startBroadcast();
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperconfig = new HelperConfig();

        (,, address vrfCoordinator,,, uint64 subId,) = helperconfig.activeNetworkConfig();
        addConsumer(raffle, vrfCoordinator, subId);
    }

    function run() external {
        address contractAddress = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);

        addConsumerUsingConfig(contractAddress);
    }
}
