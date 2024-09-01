// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test} from "lib/forge-std/src/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2_5Mock} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleTestUnit is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 50 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) return;
        _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();

        (raffle, helperConfig) = deployer.deployContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testPayNotEnoughEnterRevert() public {
        // arrange
        vm.prank(PLAYER);
        // act
        vm.expectRevert(Raffle.Raffle_NotEnoughEth.selector);
        raffle.enterRaffle();
        // assert
    }

    function testRaffleRecordsPlayerEnter() public {
        // arrange
        vm.prank(PLAYER);
        // act
        raffle.enterRaffle{value: entranceFee}();
        // assert
        address playerRecorded = raffle.getPlayer(0);
        assertEq(playerRecorded, PLAYER);
    }

    function testEnterRaffleEmitEvent() public {
        // arrange
        vm.prank(PLAYER);

        // act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);

        // assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testNoEnterWhenCalculating() public raffleEntered {
        // arrange
        raffle.performUpkeep("");

        // act/assert
        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    // CHECK UPKEEP

    function testNoBalanceUpkeepReturnFalse() public {
        // arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepFalseRaffleNotOpen() public raffleEntered {
        // arrange
        raffle.performUpkeep("");

        // act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // assert
        assert(!upkeepNeeded);
    }

    // PERFORM UPKEEP

    function testPerformUpkeepCanRunIfCheckUpkeepTrue() public raffleEntered {
        // arrange

        // act/ assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepFalse() public {
        // arrange
        uint256 currentBalance;
        uint256 numPlayers;
        Raffle.RaffleState rstate = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = address(raffle).balance;
        numPlayers = raffle.getPlayerLength();

        // act/ assert
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle_UpkeepNeeded.selector, currentBalance, numPlayers, rstate));
        raffle.performUpkeep("");
    }

    // test to get data from emitted events in our tests
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        // arrange

        // act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    // FULFILLRANDOMWORDS

    function testFulfillrandomWordsOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered {
        // arrange/ act/ assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector); // when running on fork: vm.expectRevert()
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillrandomWordsPicksWinnerResetsAndSendMoney() public skipFork raffleEntered {
        // arrange
        uint256 additionalEntrants = 3; // 4 total
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, entranceFee);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
