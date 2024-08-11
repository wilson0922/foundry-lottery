// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions


// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

/**
 * @title A sample raffle contract
 * @author Wilson Lin
 * @notice This contract is for creating a sample raffle contract
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle {
    // Errors
    error Raffle_NotEnoughEth();

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; // the duration of the lottery in seconds
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;

    // Events
    event RaffleEntered(
        address indexed player
    );

    constructor(uint256 entranceFee, uint256 interval){
        i_entranceFee=entranceFee;
        i_interval=interval;
        s_lastTimeStamp=block.timestamp;
    }
    function  enterRaffle() external payable{
        // require(msg.value<i_entranceFee,'Not enough ETH sent');
        // require(msg.value<i_entranceFee,Raffle_NotEnoughEth()); in v0.8.26 and need IR to compile

        if(msg.value<i_entranceFee){
            revert Raffle_NotEnoughEth();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    function  pickWinner() external {
        // 1. get a random number
        // 2. user the random number to pick a player
        // 3. be automatically called

        // check if enough time has passed
        if(block.timestamp-s_lastTimeStamp<i_interval){
            revert();
        }
    }

    // getters
    function getEentranceFee() external view returns (uint256){
        return i_entranceFee;
    }

    function getPlayers(uint256 index) external view returns(address) {
        return s_players[index];
    }
}