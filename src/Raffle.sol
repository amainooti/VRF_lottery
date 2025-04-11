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
contract Raffle is VRFConsumerBaseV2 {
    error NotEnoughETHSent();
    error NotEnoughTimePaassed();
    error RaffleTransferFailed();
    error Raffle_NOT_OPEN();
    error Raffle_upKeepNeeded(uint256 currentBalance, uint256 numberOfPlayers, uint256 raffleState);

    enum RaffleState {
        OPEN,
        CALCULATING
    }

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

    RaffleState private s_raffleState;

    // Events
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);

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
        s_raffleState = RaffleState.OPEN;
    }

    function enterraffle() external payable {
        if (msg.value <= i_entranceFee) {
            revert NotEnoughETHSent();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_NOT_OPEN();
        }

        s_players.push(payable(msg.sender));
        //  1. Makes Migration easier
        //  2. Makes frontend indexing easier
        emit EnteredRaffle(msg.sender);
    }

    // When the winner is supposed to be picked
    /**
     * @dev This function is called by the Chainlink Automation node call
     * The following should be true for this to return true;
     * 1. The time interval has passed between raffle runs
     * 2. The raffle is in the OPEN state
     * 3. The contract has ETH
     * 4. Implicit the subscription is funded with LINK
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp >= i_interval);
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasETH = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasETH && hasPlayers;

        return (upkeepNeeded, "0x0");
    }

    /*
    1. Get a random number
    2. Use a random number to get a player
    3. Be automatically called
    
    */
    function performUpkeep(bytes calldata /* performData */ ) external {
        // Check if enough time has passed

        (bool upkeepNeeded,) = checkUpkeep("");

        if (!upkeepNeeded) {
            revert Raffle_upKeepNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;

        i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, NUM_WORDS
        );
    }

    // CEI: Checks, Effects, Interactions
    function fulfillRandomWords(uint256, /* requestId */ uint256[] memory randomWords) internal override {
        // checks
        // Effect (our own contract)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recent_winner = winner;
        s_raffleState = RaffleState.OPEN;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        emit WinnerPicked(winner);

        //  Interactions (Our own contracts)
        (bool success,) = winner.call{value: address(this).balance}("");

        if (!success) {
            revert RaffleTransferFailed();
        }
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }
}
