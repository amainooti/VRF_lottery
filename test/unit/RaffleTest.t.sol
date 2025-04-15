// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/Deployraffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test {
    // Events
    event EnteredRaffle(address indexed player);

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

    function testPerformUpkeepUpdatesraffleStateAndEmitsRequest()
        public
        enterRaffleAndEnoughtimehaspassed
    {
        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emit the requestID
        Vm.Log[] memory entries = vm.getRecordedLogs();

        for (uint i = 0; i < entries.length; i++) {
            console.log("Log Entry", i);
            console.logBytes32(entries[i].topics[0]);
            console.log("Data:");
            console.logBytes(entries[i].data);
            console.log("Emitter:");
            console.logAddress(entries[i].emitter);
        }
    }
}
