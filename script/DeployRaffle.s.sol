// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
// Uncomment the next line if CreateSubscription is part of your project
// import {CreateSubscription} from "./CreateSubscription.s.sol";

contract DeployRaffle is Script {
    function run() public {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        // Deploy HelperConfig to fetch the network-specific configuration
        HelperConfig helperConfig = new HelperConfig();

        // Fetch the configuration from HelperConfig
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // Uncomment the following lines if subscription creation is required
        /*
        if (config.subscriptionId == 0) {
            // Ensure CreateSubscription is properly imported and implemented
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) = createSubscription.createSubscription(config.vrfCoordinator);
        }
        */

        // Start broadcasting transactions to the network
        vm.startBroadcast();

        // Deploy the Raffle contract with the fetched configuration
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Return the deployed contracts
        return (raffle, helperConfig);
    }
}
