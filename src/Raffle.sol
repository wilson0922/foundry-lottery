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

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample raffle contract
 * @author Wilson Lin
 * @notice This contract is for creating a sample raffle contract
 * @dev Implements Chainlink VRFv2.5
 */
abstract contract Raffle is VRFConsumerBaseV2Plus{
    // Type declaration
    enum RaffleState{
        OPEN, // 0
        CALCULATING // 1
    }

    // Errors
    error Raffle_NotEnoughEth();
    error Raffle_TransferFailed();
    error Raffle_RaffleNotOpen();
    error Raffle_UpkeepNeeded(uint256 balance, uint256 playLength, uint256 raffleState);

    // State variables
    uint16 private constant REQUEST_CONFIRMATIONS=3;
    uint32 private constant NUM_WORDS=1;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; // the duration of the lottery in seconds
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    // Events
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(uint256 entranceFee, uint256 interval,address vrfCoordinator, bytes32 gasLane, uint256 subscriptionId, uint32 callbackGasLimit) VRFConsumerBaseV2Plus (vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash=gasLane;
        i_subscriptionId=subscriptionId;
        i_callbackGasLimit=callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState=RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value<i_entranceFee,'Not enough ETH sent');
        // require(msg.value<i_entranceFee,Raffle_NotEnoughEth()); in v0.8.26 and need IR to compile

        if (msg.value < i_entranceFee) {
            revert Raffle_NotEnoughEth();
        }

        if(s_raffleState!=RaffleState.OPEN){
            revert Raffle_RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev This is the function that Chainlink node will call to see if the lottery is ready to have a winner picked
     * The following should be true in order for upkeepNeeded to be true
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH (has players)
     * 4. Implicitly, your subscription has LINK
     * @param -ignored 
     * @return upkeepNeeded  - true if it's time to restart lottery
     * @return -ignored 
     */

    function checkUpkeep(bytes memory /*checkData*/ ) public view returns (bool upkeepNeeded, bytes memory /* performData */){
         bool timeHasPassed= (block.timestamp - s_lastTimeStamp >= i_interval);
         bool isOpen=s_raffleState==RaffleState.OPEN;
         bool hasBalance=address(this).balance>0;
         bool hasPlayers=s_players.length>0;
         upkeepNeeded = timeHasPassed&&isOpen&&hasBalance&&hasPlayers;
         return (upkeepNeeded,"");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        // 1. get a random number
        // 2. user the random number to pick a player
        // 3. be automatically called

        // check if enough time has passed
        (bool upkeepNeeded,)=checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle_UpkeepNeeded(address(this).balance,s_players.length,uint256(s_raffleState));
        }

        s_raffleState= RaffleState.CALCULATING;

        // get our random number 2.5
        // 1. request RNG (we make a tx to request the RNG)
        // 2. get RNG (chainlink oracle will senc a tx to us or somewhere)

        

        VRFV2PlusClient.RandomWordsRequest memory request= VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: false
                    })
                )
            });

            s_vrfCoordinator.requestRandomWords(
            request
        );
        
    }

    // functions methodology- CEI: Checks, Effects, Interactions pattern
    function fulfillRandomWords(uint256 /*requestId*/, uint256[] calldata randomWords) internal virtual override{
        // Checks
        // s_player =10
        // rng = 12 (actually 74014580145687014514567151)
        // 12 % 10 = 2 

        // Effect (Internal Contract State)
        uint256 indexeOfWinner=randomWords[0] % s_players.length;
        address payable recentWinner=s_players[indexeOfWinner];
        s_recentWinner=recentWinner;

        s_players= new address payable[](0);
        s_lastTimeStamp=block.timestamp;
        s_raffleState=RaffleState.OPEN;
        emit WinnerPicked(s_recentWinner);

        // Interactions (External Contract Interactions)
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if(!success){
            revert Raffle_TransferFailed();
        }
    }

    // getters
    function getEentranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayers(uint256 index) external view returns (address) {
        return s_players[index];
    }
}
