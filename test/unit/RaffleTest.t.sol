// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {CodeConstants, HelperConfig} from "script/HelperConfig.s.sol";

contract RaffleTest is CodeConstants, Test {
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

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // set block.timestamp to 'block.timestamp + interval',
        // so we can be sure that the raffle winner isn't blocked by
        // not having passed enough time
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1); // increment block.number

        _;
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }

        _;
    }

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
        assertEq(uint256(raffleState), uint256(Raffle.RaffleState.OPEN));
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

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating()
        public
        raffleEntered
    {
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
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen()
        public
        raffleEntered
    {
        // Arrange
        raffle.performUpkeep(""); // this should close the raffle

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertFalse(upkeepNeeded);
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
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood()
        public
        raffleEntered
    {
        // Arrange

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertTrue(upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                             PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/
    function testPerformUpkeepRunsIfCheckedUpkeepIsTrue() public raffleEntered {
        /*
        I followed the Cyfrin course implementation with this, but in reality this test should
        mock checkUpkeep so that we test the behaviour of performUpkeep when its only input
        is the output of checkUpkeep.
        */

        // Arrange

        // Act
        // it would be better to use .call(...), which will be covered later in the course
        // this test will succeed because performUpkeep fails in the wrong conditions.
        (bool checkUpkeep, ) = raffle.checkUpkeep("");
        raffle.performUpkeep("");

        // Assert
        assertTrue(checkUpkeep);
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        /*
        I followed the Cyfrin course implementation with this, but in reality this test should
        mock checkUpkeep so that we test the behaviour of performUpkeep when its only input
        is the output of checkUpkeep.
        */

        // Arrange
        uint256 raffleStartBalance = address(raffle).balance;

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        
        uint256 currentBalance = raffleStartBalance + entranceFee;
        uint256 numPlayers = 1;
        Raffle.RaffleState rState = raffle.getRaffleState();

        // Act
        // it would be better to use .call(...), which will be covered later in the course
        // this test will succeed because performUpkeep fails in the wrong conditions.
        (bool checkUpkeep, ) = raffle.checkUpkeep("");

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__RaffleNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        raffle.performUpkeep("");

        // Assert
        assertFalse(checkUpkeep);
    }

    function testPerformUpkeepUpdateRaffleStateAndEmitsRequestedId()
        public
        raffleEntered
    {
        // Arrange

        // Act
        // Logs from events emitted by performUpkeep are stored in an array that we can inspect
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // this is 0-indexed, but the first log emitted by the function
        // is going to be emitted by the VrfCoordinator itself.
        // The 0th topic is also reserved
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assertGt(uint256(requestId), 0);
        assertEq(uint256(raffleState), uint256(Raffle.RaffleState.CALCULATING));
    }

    /*//////////////////////////////////////////////////////////////
                           FULFILLRANDOMWORDS
    //////////////////////////////////////////////////////////////*/
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEntered skipFork {
        /* fuzz testing - the test runs multiple times with different random values for randomRequestId
        Configurable in foundry.toml. E.g.: to run 1000 times
        [fuzz]
        runs = 1000
        */

        // Arrange

        // Act
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );

        // Assert
    }

    function checkPlayerBalance(uint256 startingIndex, uint256 totalEntrants, address player, uint256 startingBalance) internal {
        uint256 expectedWinnerIndex = 1;
        address expectedWinner = address(uint160(expectedWinnerIndex + startingIndex));
        uint256 prize = totalEntrants * entranceFee;
        uint256 expectedWinnerEndBalance = startingBalance - entranceFee + prize;
        if (player == expectedWinner) {
            assertEq(player.balance, expectedWinnerEndBalance);
        } else {
            assertEq(player.balance, startingBalance - entranceFee);
        }
    }

    function checkPlayerBalances(uint256 startingIndex, uint256 totalEntrants, uint256 startingBalance) private {
        for (
            uint256 i = startingIndex;
            i < startingIndex + totalEntrants;
            i++
        ) {
            address playerAddress = address(uint160(i)); // convert any number to an address
            checkPlayerBalance(startingIndex, totalEntrants, playerAddress, startingBalance);
        }
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public skipFork {
        // Arrange
        uint256 totalEntrants = 4;
        uint256 startingIndex = 1;
        uint256 startingBalance = 1 ether;

        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);

        for (
            uint256 i = startingIndex;
            i < startingIndex + totalEntrants;
            i++
        ) {
            address newPlayer = address(uint160(i)); // convert any number to an address
            hoax(newPlayer, startingBalance);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestIdBytes = entries[1].topics[1];
        uint256 requestId = uint256(requestIdBytes);
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2).fulfillRandomWords(
            requestId,
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 endingTimeStamp = raffle.getLastTimeStamp();

        assertEq(uint256(raffleState), uint256(Raffle.RaffleState.OPEN));
        assertGt(endingTimeStamp, startingTimeStamp);

        checkPlayerBalances(startingIndex, totalEntrants, startingBalance);
    }
}
