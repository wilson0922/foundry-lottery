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

    constructor(uint256 entranceFee){
        i_entranceFee=entranceFee;
    }
    function  enterRaffle() public payable{
        // require(msg.value<i_entranceFee,'Not enough ETH sent');
        // require(msg.value<i_entranceFee,Raffle_NotEnoughEth()); in v0.8.26 and need IR to compile
        
        if(msg.value<i_entranceFee){
            revert Raffle_NotEnoughEth();
        }
    }

    function  pickWinner() public {}

    // getters
    function getEentranceFee() external view returns (uint256){
        return i_entranceFee;
    }
}