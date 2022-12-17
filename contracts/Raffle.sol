//paso del contrato

/*
   1-- Preparar el contrato Raffle
   2-- Enter the lottery(paying some amount)
    3-- Pick a random winner (verifiably random)
    4-- Winner to be selected every X minutes -> completly automate
    5-- Chainlink Oracle -> Randomness, Automated Execution (Chainlink Keeper)
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";


error Raffle__NotEnoughETHEntered();
error Raffle__TransferFailed();
error Raffle__RaffleNotOpen();
error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffeState);

/** 
 *@title  Ejemplo de un contrato de rifas 
 * @author yoel torres
 * @notice Este contrato es para crear un temporizador decentralizado para rifas
 * @dev este implementa chainlink coordinator y chainlik keeper
 * 
 * 
 * 
 */



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
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

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
        uint16 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane; // Cuanto estas dispuesto a pagar
        i_suscripcionId = suscripcionId; //ID de la suscripcion de nuestro contrato a chainlink
        i_callbackGasLimit = callbackGasLimit;
        s_rafflestate = RaffleState.OPEN; // Inicializo la variable con enum
        s_lastTimeStamp = block.timestamp;
    i_interval = interval;
    
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHEntered();
        }

        //Valido si la raffle no esta abierta, de lo contrario la reyecto
        if (s_rafflestate != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
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


    //Este me valida si se cumple todas las condiciones para poder hacer la solicitud de un nuevo ganador
    function checkUpkeep(bytes memory /*checkData*/) public override returns(bool upkeepNeeded, bytes memory /* perfomData*/){

        bool isOpen  = (RaffleState.OPEN == s_rafflestate);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = address(this).balance > 0;

         upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);

    
    }

    //Para que se mas barato uso external, ya que solo mi contrato puede llamarlo.
    function performUpkeep( bytes calldata /*perfomData*/) external override {
        //Request the random number
        //Once we get it, do something with it
        //2 transaction process

        (bool upkeepNeeded, /*Aqui va el return del perfomdata */) = checkUpkeep(""); 

            //si no se cumple la condicion devuelta por el checkupkeep
            if(!upkeepNeeded){
                    revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_rafflestate));
            }



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


    

   
//Funcion para obtener un numero random
    function fulfillRandomWords(
        uint256 /* requestId*/,
        uint256[] memory randomWords
    ) internal override {
        //Esto se conoce como modulo, para sacar un numero de un un numero masivo
        uint256 indexOfWinner = randomWords[0] % s_players.length; // Esto se hace asi, ya que randomwords, nos devuelve un numero enorme, por  lo que obtenemos solamente el residuo de la divicion, del numero entre la cantidad de jugadores.
        address payable recentWinner = s_players[indexOfWinner];

        s_recentWinner = recentWinner;
        s_rafflestate = RaffleState.OPEN; // aqui vuelvo a poner la variable en open

        //Despues de sacar un ganador, necesito resetear mi arreglo.
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

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

    function getRaffleState() public view returns (RaffleState) {
        return s_rafflestate;
    }

//Este get es pure, ya que estoy leyendo una constante, por lo que no tengo que hacerla una view
    function getNumWords() public pure returns (uint256) {
        return NUMWORDS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    //Esta tambie lee una constante
    function getRequestConfirmation() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }



}
