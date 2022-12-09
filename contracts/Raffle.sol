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
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

//import "./PriceConverter.sol";
error Raffle__NotEnoughETHEntered();
error Raffle__TransferFailed();
error Raffle__NotOpen();

//Implemento estas 2 interfaces.
contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {
    /*Type declarations */

    enum RaffleState {
        OPEN,
        CALCULATING
    } //uint256 0= OPEN, 1= CALCULATING

    //state Variables
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_suscripcionId;
    uint16 private immutable i_callbackGasLimit;

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUMWORDS = 2;

    //Lottery Variables

    address private s_recentWinner;
    //Variable creada del tipo de dato Enum
    RaffleState private s_rafflestate;

    /*Events */
    //Es una buena practica que los eventos tenga el nombre de la funcion que van a usar, pero invertido en este caso enterRaffle, tiene un evento llamado raffleEnter
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

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
        s_rafflestate = RaffleState.OPEN; // Inicializo la variable con enum
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHEntered();
        }

        //Valido si la raffle no esta abierta, de lo contrario la reyecto
        if (s_rafflestate != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }

        s_players.push(payable(msg.sender));

        emit RaffleEnter(msg.sender);
    }

    /**
     * @dev Esta la funcion que chainlink keeper nodes llaman para ver si 'Upkeepneed' retorna un true.
     * necesita devolver un true, para que me genere otro numero aleatorio.
     *
     * Se debe de cumplir lo siguiente para que sea true:
     *
     * 1- El tiempo de intervalo deberia pasar.
     * 2- La loteria deberia tener al menos 1 jugador,  y tener algunos eth
     * 3- Nuestra subscricion tiene link de fondos
     * 4- La loteria deberia esta en estado "abierto", si queremos participar de esta loteria.
     *
     */

    function checkUpkeep(bytes calldata /*checkData*/) external override {}

    //Para que se mas barato uso external, ya que solo mi contrato puede llamarlo.
    function requestRandomWinner() external {
        //Request the random number
        //Once we get it, do something with it
        //2 transaction process

        s_rafflestate = RaffleState.CALCULATING; // actualizo mi valor de s_raffle para evitar que alguien entre mientras se este calculando
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
        uint256 /* requestId*/,
        uint256[] memory randomWords
    ) internal override {
        //Esto se conoce como modulo, para sacar un numero de un un numero masivo
        uint256 indexOfWinner = randomWords[0] % s_players.length; // Esto se hace asi, ya que randomwords, nos devuelve un numero enorme, por  lo que obtenemos solamente el residuo de la divicion, del numero entre la cantidad de jugadores.
        address payable recentWinner = s_players[indexOfWinner];

        s_recentWinner = recentWinner;
        s_rafflestate = RaffleState.OPEN; // aqui vuelvo a poner la variable en open
        (bool success, ) = recentWinner.call{value: address(this).balance}(""); //le envio todo el dinero al ganador

        if (!success) {
            revert Raffle__TransferFailed(); // Si no funciona lo revierto
        }

        emit WinnerPicked(recentWinner);
    }

    /*View / Pure functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }
}
