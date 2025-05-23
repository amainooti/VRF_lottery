// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/Deployraffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    // Events
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);

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
    address link;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link
        ) = helperConfig.activeNetworkConfig();

        // Give player some funds
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    // Enter raffle

    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange

        vm.prank(PLAYER);

        // Act
        vm.expectRevert(Raffle.NotEnoughETHSent.selector);

        // Assert
        raffle.enterraffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterraffle{value: entranceFee}();
        console.log(entranceFee);
        console.log("Contract balance:", address(raffle).balance);
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testemitEventOnentrance() public {
        vm.prank(PLAYER);

        vm.expectEmit(true, false, false, false, address(raffle));

        emit EnteredRaffle(PLAYER);

        raffle.enterraffle{value: entranceFee}();
    }

    function testCanEnterWhenRaffleIsCalculating()
        public
        enterRaffleAndEnoughtimehaspassed
    {
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle_NOT_OPEN.selector);
        vm.prank(PLAYER);
        raffle.enterraffle{value: entranceFee}();
    }

    function testUpKeepReturnsFalseIfItHasNoBalance() public {
        // Arrange

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
        // Assert
    }

    function testCheckUpKeepReturnsFalseIfRaffleNotOpen()
        public
        enterRaffleAndEnoughtimehaspassed
    {
        // Arrange

        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    function testUpKeepReturnsFalseIfEnoughTimeHasPassed() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertEq(upkeepNeeded, false);
        // Assert
    }

    function testUpKeepReturnsTrueIfParamsAreGood()
        public
        enterRaffleAndEnoughtimehaspassed
    {
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertEq(upkeepNeeded, true);
    }

    modifier enterRaffleAndEnoughtimehaspassed() {
        // player has entered, has eth and is open by default from deployment
        vm.prank(PLAYER);
        raffle.enterraffle{value: entranceFee}();

        // Enough time has passed
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpKeepIsTrue()
        public
        enterRaffleAndEnoughtimehaspassed
    {
        // Act
        raffle.performUpkeep("");
    }

    function testperformUpKeepRevertsIfCheckUpKeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 num_of_players = 0;
        uint256 raffleState = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle_upKeepNeeded.selector,
                currentBalance,
                num_of_players,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesraffleStateAndEmitsRequestId()
        public
        enterRaffleAndEnoughtimehaspassed
    {
        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emit the requestID
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[2];

        Raffle.RaffleState rstate = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assertEq(uint256(rstate), 1);
    }

    function testFufillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomIdNumber
    ) public enterRaffleAndEnoughtimehaspassed {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomIdNumber,
            address(raffle)
        );
    }

    function testFulfillRandomNumbersPicksAWinnerResetsAndSendsMoney()
        public
        enterRaffleAndEnoughtimehaspassed
    {
        // Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;

        for (uint256 i = startingIndex; i < additionalEntrants; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterraffle{value: entranceFee}();
        }
        // Act

        /*
            pretend to be chainlink vrf
        
         */

        uint256 prize = entranceFee * (additionalEntrants + 1);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[2];
        uint256 previousTimeStamp = raffle.getTimeStamp();

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert

        assertEq(uint256(raffle.getRaffleState()), 0);
        assertTrue(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(previousTimeStamp > raffle.getTimeStamp());

        vm.expectEmit(true, false, false, false, address(raffle));
        emit WinnerPicked(PLAYER);
        assert(
            raffle.getRecentWinner().balance ==
                STARTING_USER_BALANCE + prize - entranceFee
        );
    }
}
