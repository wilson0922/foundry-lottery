// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

/**
 * @title A sample raffle contract
 * @author Wilson Lin
 * @notice This contract is for creating a sample raffle contract
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle {
    uint256 private immutable i_entranceFee;

    constructor(uint256 entranceFee){
        i_entranceFee=entranceFee;
    }
    function  enterRaffle() public payable{}

    function  pickWinner() public {}

    // getters
    function getEentranceFee() external view returns (uint256){
        return i_entranceFee;
    }
}