// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";

contract RaffleTest is Test {
    HelperConfig helperConfig;
    Raffle raffle;

    address public PLAYER = makeAddr("player");
    uint256 constant STARTING_PLAYER_BALANCE = 10 ether;

    event PlayerEnteredRaffle(
        address indexed playerAddress,
        uint256 indexed value
    );

    uint256 subscriptionId;
    bytes32 gasLane;
    uint256 interval;
    uint256 entranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();

        HelperConfig.NetworkConfig memory networkConfig = helperConfig
            .getConfig();

        subscriptionId = networkConfig.subscriptionId;
        gasLane = networkConfig.gasLane;
        interval = networkConfig.interval;
        entranceFee = networkConfig.entranceFee;
        callbackGasLimit = networkConfig.callbackGasLimit;
        vrfCoordinatorV2 = networkConfig.vrfCoordinatorV2;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleIsInitialisedInOpenState() external view {
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(raffleState == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                              ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/
    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);

        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();

        assertEq(raffle.getPlayer(0), PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit PlayerEnteredRaffle(PLAYER, entranceFee);

        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // set block.timestamp to 'block.timestamp + interval',
        // so we can be sure that the raffle winner isn't blocked by
        // not having passed enough time
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1); // increment block.number
        raffle.performUpkeep("");

        // We've now added a player to the raffle,
        // and set the raffle state to CALCULATING.
        // New players can't join
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                              CHECK UPKEEP
    //////////////////////////////////////////////////////////////*/
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1); // increment block.number
        
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1); 
        raffle.performUpkeep("");  // this should close the raffle

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfNotEnoughTimeHasPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }
}
