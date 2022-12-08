//paso del contrato

/*
   1-- Preparar el contrato Raffle
   2-- Enter the lottery(paying some amount)
    3-- Pick a random winner (verifiably random)
    4-- Winner to be selected every X minutes -> completly automate
    5-- Chainlink Oracle -> Randomness, Automated Execution (Chainlink Keeper)
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

//import "./PriceConverter.sol";
error Raffle__NotEnoughETHEntered();

contract Raffle is VRFConsumerBaseV2 {
    //state Variables
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_suscripcionId;
    uint16 private immutable i_callbackGasLimit;

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUMWORDS = 2;

    /*Events */
    //Es una buena practica que los eventos tenga el nombre de la funcion que van a usar, pero invertido en este caso enterRaffle, tiene un evento llamado raffleEnter
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        address vrfCoordinatorV2,
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 suscripcionId,
        uint16 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane; // Cuanto estas dispuesto a pagar
        i_suscripcionId = suscripcionId; //ID de la suscripcion de nuestro contrato a chainlink
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHEntered();
        }

        s_players.push(payable(msg.sender));

        emit RaffleEnter(msg.sender);
    }

    //Para que se mas barato uso external, ya que solo mi contrato puede llamarlo.
    function requestRandomWinner() external {
        //Request the random number
        //Once we get it, do something with it
        //2 transaction process

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_suscripcionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUMWORDS
        );

        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {}

    /*View / Pure functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }
}
