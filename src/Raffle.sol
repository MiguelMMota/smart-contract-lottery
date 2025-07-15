// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


/**
 * @title A sample Raffle contract
 * @author Miguel Mota
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__NotEnoughTimePassedSinceLastRaffle();

    /* State variables */
    uint256 private immutable i_entranceFee;
    // @dev the duration of the lottery in seconds
    uint256 private immutable i_lotteryInterval;
    address payable[] private s_players;
    uint256 private s_lastTimestamp;

    /* Events */
    event playerEnteredRaffle (
        address indexed playerAddress,
        uint256 indexed value
    );

    /* Modifiers */

    /* Functions */
    constructor(uint256 entranceFee, uint256 lotteryInterval) {
        i_entranceFee = entranceFee;
        i_lotteryInterval = lotteryInterval;
        s_lastTimestamp = block.timestamp;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        s_players.push(payable(msg.sender));
        emit playerEnteredRaffle(msg.sender, msg.value);
    }

    function pickWinner() external {
        // check to see if enough time has passed
        if (block.timestamp - s_lastTimestamp < i_lotteryInterval) {
            revert Raffle__NotEnoughTimePassedSinceLastRaffle();
        }



        

        s_lastTimestamp = block.timestamp;
    }

    /** Getter functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}