//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
contract RaffleTest is Test{
        Raffle public raffle;
        HelperConfig public helperConfig;

        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;

        event RaffleEntered(address indexed player);
        event WinnerPicked(address indexed winner);


        //make some users to interact with raffle
        address public PLAYER = makeAddr("player"); //makeaddr converts str to address
        uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;
    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract(); //the deployer contract returns raffle and config
        HelperConfig.NetworkConfig memory config= helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;
    }
    function testRaffleInitializesInOpenState() public view{
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPayEnough() public {
        //Arrange
        vm.prank(PLAYER);
        //Act / Assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public{
        //Arrange
        vm.prank(PLAYER); //pretending to be the player
        //Act
        raffle.enterRaffle{value: entranceFee}();
        //Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }
    function testEnterRaffleEmitsEvent() public {
            vm.prank(PLAYER);
            vm.expectEmit(true, false, false,false, address(raffle)); // 1 true because 1 indexed parameter
            emit RaffleEntered(PLAYER);

            raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee};
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number+1);
        raffle.performUpkeep("");

        vm.expectRevert();
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpKeepIsTrue() public {
    // Arrange
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();
    vm.warp(block.timestamp + interval + 1); // Fast-forward time
    vm.roll(block.number + 1);              // Increment block number

    // Act
    (bool upkeepNeeded,) = raffle.checkUpkeep(""); // Check if upkeep is needed
    assert(upkeepNeeded); // Assert that upkeep is indeed needed

    // Call performUpkeep
    raffle.performUpkeep("");

    // Assert that the state has changed to CALCULATING
    assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
}


    }

