// SPDX-License-Identifier: MIT

// Layout of functions

// constructor

// receive function (if exists)

// fallback function (if exists)

// external

// public

// internal

// private

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A sample of a raffle contract
 * @author Amaino Oti
 * @notice This Contract is for creating a sample raffle
 * @dev Implements Chainlink VRF v2.0
 */

contract Rafflle is VRFConsumerBaseV2 {
    error NotEnoughETHSent();
    error NotEnoughTimePaassed();

    // state variables
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    // @dev Duration of the lottery in seconds
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address private s_recent_winner;

    // Events
    event EnteredRaffle(address indexed player);

    constructor(
        uint256 _entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = _entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterraffles() external payable {
        if (msg.value <= i_entranceFee) {
            revert NotEnoughETHSent();
        }

        s_players.push(payable(msg.sender));
        //  1. Makes Migration easier
        //  2. Makes frontend indexing easier
        emit EnteredRaffle(msg.sender);
    }

    /*
    1. Get a random number
    2. Use a random number to get a player
    3. Be automatically called
    
    */
    function pickWinner() public {
        // Check if enough time has passed

        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert NotEnoughTimePaassed();
        }

        //1. Request RGN <-- Random Number Generator
        //2. Get a random number
        //3. Use a random number to get a player
        //4. Send them the money

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
    }

    function fufillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recent_winner = winner;
        (bool success, ) = winner.call{value: address(this).balance}("");
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
