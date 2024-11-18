// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle contract
 * @author ...
 * @notice This contract is a simple Raffle contract
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__transferFailed();
    error Raffle__RaffleNotOpen();
  

    /*Type Declarations*/
    enum RaffleState {
        OPEN,            //0
        CALCULATING      //1
    }

    /*State Variables*/
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    uint256 private immutable i_interval;
    uint256 private s_LastTimestamp;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit; // Changed to uint32
    uint32 private constant NUM_WORDS = 1; // Changed to uint32
    address private s_recentWinner;
    RaffleState private s_raffleState; //start as open


   

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit // Changed the type to uint32

    )
        VRFConsumerBaseV2Plus(vrfCoordinator)
    {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_LastTimestamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState(0);
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if(s_raffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

        /**
     * @dev This is the function that the Chainlink nodes will call to
     * see if the lottery is ready to have a winner picked.
     * The following should be true in order for upkeepNeeded to be true;
     * 1. The time interval has passed between reffle runs
     * 2. The lottery is open
     * 3. Your contract has ETH
     * 4. Implicitly, your subscription has a LINK  
     * @param - ignored
     * @return upkeepNeeded - true if its time to restart the lottery
     * @return - ignored
     */

    function checkUpkeep(bytes memory /*checkData*/) public view
    returns (bool upkeepNeeded, bytes memory /*performData*/){
        bool timeHasPassed = ((block.timestamp - s_LastTimestamp) >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length >0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, hex"");
    }

    function performUpkeep(bytes memory /* performData */) external {
        (bool upkeepNeeded,) =  checkUpkeep("");
        if (!upkeepNeeded){
            revert();// Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        if ((block.timestamp - s_LastTimestamp) < i_interval) {
            revert();
        }
        s_raffleState = RaffleState.CALCULATING;

        // Request a random number using VRF
        VRFV2PlusClient.RandomWordsRequest memory para = VRFV2PlusClient.RandomWordsRequest(
            {
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit, // Properly cast to uint32
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            }
            
        );
        VRFV2PlusClient.RandomWordsRequest memory request = para;
        
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request); // Pass the request here. a request is made to chainlink VRF 
        
    }

    // The function must include the full body, even if empty for now
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        //Checks
        // Logic for handling the randomWords will go here in the future
        //Effects (Internal contract state)
        uint256 indexOfWinner = randomWords[0] % s_players.length ;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_LastTimestamp = block.timestamp;

        //Interactions (External Contract State)
        (bool success,) =recentWinner.call{value: address(this).balance}("");
        if(!success){
            revert Raffle__transferFailed();
        }
        emit WinnerPicked(s_recentWinner);
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState){
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address){
        return s_players[indexOfPlayer];
    }
}
