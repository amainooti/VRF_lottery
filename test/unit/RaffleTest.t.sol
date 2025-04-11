// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/Deployraffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        (entranceFee, 
        interval, 
        vrfCoordinator, 
        gasLane, 
        subscriptionId, 
        callbackGasLimit) = helperConfig.activeNetworkConfig();
    }

    function testRaffleInitializesInOpenState() public view{
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN); 
    }


// Enter raffle 

    function testRaffleRevertsWhenYouDontPayEnough() public {
    // Arrange

    vm.prank(PLAYER);

    // Act
    vm.expectRevert(Raffle.NotEnoughETHSent.selector);
    raffle.enterraffle();
    // Assert
    }
}
