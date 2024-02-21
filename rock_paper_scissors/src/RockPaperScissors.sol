// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RockPaperScissors is ReentrancyGuard {
    using SafeERC20 for IERC20;
    enum Move { None, Rock, Paper, Scissors }
    enum GameState { Open, Player1Commited, Player2Commited, OnePlayerRevealed, WinnerAnnounced }
    enum GameWinner { None, Player1, Player2, Draw}

    struct Player {
        address addr;
        bytes32 moveHash;
        Move move;
    }

    struct Game {
        GameState state;
        Player player1;
        Player player2;
        GameWinner result;
        uint wager;
    }
    // errors
    error InvalidGameState(GameState _state);

     // Events
    event MoveCommitted(address player, uint gameId, uint wager, uint fee);
    event JackpotWon(address winner, uint amount);
    event GameResult(uint _gameId, GameWinner _winner);

    // Constants
    uint public constant MIN_WAGER_AMOUNT = 1;
    
    // Payment token for wagers
    IERC20 public paymentToken;
    
    // Minimum wager amount is 1    
    uint public wagerAmount;
    // Fee percentage to be charged for each wager, values in range (0,99)
    uint public feePercentage;   
    // Jackpot amount is incremented by the fee charged for each wager
    uint public collectedAmount;
    // Minimum jackpot amount is 100 x the wagerAmount
    uint public minJackpotAmount;
    // Minimum consecutive wins required to win the jackpot
    uint public minConsecutiveWins;

    mapping(uint => Game) public games;
    uint public gameCounter;
    mapping(address => uint) public playerLastGame;

    uint public numberOfPlayers;
    mapping(uint => address) public allPlayers;
    // Consecutive wins by a player
    mapping(address => uint) public consecutiveWins;


    constructor(address _paymentToken, uint _wagerAmount, uint _feeAmount, uint _minConsecutiveWins, uint _minJackpotAmount) {
        paymentToken = IERC20(_paymentToken);
        if(_wagerAmount == 0 ) _wagerAmount = MIN_WAGER_AMOUNT; 
        wagerAmount = _wagerAmount;
        if(_feeAmount > 99) {
            feePercentage = 99;
        } else {
            feePercentage = _feeAmount;
        }
        minConsecutiveWins = _minConsecutiveWins;
        minJackpotAmount = _minJackpotAmount;
    }

    // ================================= VIEW FUNCTIONS =================================================

    function getGameInfo(uint _gameId) external view returns(Game memory) {
        return games[_gameId];
    }

    function getPlayerInfoForGame(uint _gameId, uint _playerIndex) external view returns(Player memory) {
        if(_playerIndex == 0) {
            return games[_gameId].player1;
        } else {
            return games[_gameId].player2;
        }
    }

    function getWinner(uint _gameId) external view returns(uint) {
        return uint(games[_gameId].result);
    }

    function getLeaderboard() external view returns (address[] memory leaderboard, uint[] memory wins) {
        leaderboard = new address[](numberOfPlayers);
        wins = new uint[](numberOfPlayers);
        address player;
        uint winCount;
        uint j;
        for (uint i = 0; i < numberOfPlayers; i++) {
            player = allPlayers[i];
            winCount = consecutiveWins[player];
            j = i;
            while (j > 0 && wins[j - 1] < winCount) {
                wins[j] = wins[j - 1];
                leaderboard[j] = leaderboard[j - 1];
                j--;
            }
            wins[j] = winCount;
            leaderboard[j] = player;
        }

        return (leaderboard, wins);
    }

    function hashMove(Move _move, string memory _nonce) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(_move, _nonce));
    }

    // ================================= EXTERNAL FUNCTIONS =================================================

    function commitMove(bytes32 _moveHash) external nonReentrant {
        require(paymentToken.balanceOf(msg.sender) >= wagerAmount, "Insufficient funds to play");
        require(paymentToken.allowance(msg.sender, address(this)) >= wagerAmount, "Insufficient allowance");
        require(_moveHash != 0, "Invalid move hash");

        uint gameId = _commitMove(_moveHash);
        paymentToken.safeTransferFrom(msg.sender, address(this), wagerAmount);
        uint netWager = (wagerAmount * (100 - feePercentage) * 1e16) / 1e18;
        collectedAmount += wagerAmount - netWager; // Assuming fee contributes to jackpot
        games[gameId].wager = netWager;
        
        emit MoveCommitted(msg.sender, gameId, netWager, wagerAmount - netWager);
    }

    function revealMoveForGame(uint _gameId, Move _move, string memory _nonce) external nonReentrant {
        _revealMove(_gameId, _move, _nonce);
    }

    function revealMoveForLastGame(Move _move, string memory _nonce) external nonReentrant {
        _revealMove(playerLastGame[msg.sender], _move, _nonce);
    }

    // ================================= INTERNAL FUNCTIONS =================================================

    function _getAvailableGame() internal returns(uint lastGameId) {
        if(gameCounter > 0 && games[gameCounter].state < GameState.Player2Commited) {
            lastGameId = gameCounter;
        } else {
            lastGameId = ++gameCounter;
        }
    }
    
    
    function _commitMove(bytes32 _moveHash) internal returns (uint){
        
        uint lastGameId = _getAvailableGame();
        require(playerLastGame[msg.sender] != lastGameId, "Already played" );
              

        address player1 = games[lastGameId].player1.addr;
        address player2 = games[lastGameId].player2.addr;
        require(player1 != msg.sender || player2 != msg.sender, "Player already played" );

        // Add new player if has not played yet 
        if(playerLastGame[msg.sender] == 0) {
            allPlayers[numberOfPlayers++] = msg.sender;
        }
        playerLastGame[msg.sender] = lastGameId;

        if(player1 != address(0) && player2 == address(0)) {
            games[lastGameId].player2 = Player({
                addr: msg.sender,
                moveHash: _moveHash,
                move: Move.None
            });
            games[lastGameId].state = GameState.Player2Commited;
        } else if(player1 == address(0)) {
            games[lastGameId].player1 = Player({
                addr: msg.sender,
                moveHash: _moveHash,
                move: Move.None
            });
            games[lastGameId].state = GameState.Player1Commited;
        } else {
            revert InvalidGameState(games[lastGameId].state);
        }
        return lastGameId;

    }

    function _revealMove(uint _gameId, Move _move, string memory _nonce) internal {
        GameState gameState = games[_gameId].state;
        address player1 = games[_gameId].player1.addr;
        address player2 = games[_gameId].player2.addr;
        require(player1 == msg.sender || player2 == msg.sender, "Not in reveal phase");
        require(_move != Move.None, "Invalid move");
        require(gameState >= GameState.Player2Commited, "Invalid state");
        bytes32 moveHash = keccak256(abi.encodePacked(_move, _nonce));

        if (msg.sender == player1) {
            require(moveHash == games[_gameId].player1.moveHash, "Hash mismatch");
            games[_gameId].player1.move = _move;
        } else {
            require(moveHash == games[_gameId].player2.moveHash, "Hash mismatch");
            games[_gameId].player2.move = _move;
        }
        if(gameState == GameState.Player2Commited) {
            games[_gameId].state = GameState.OnePlayerRevealed;
        }
        else {
            games[_gameId].state = GameState.WinnerAnnounced;
            GameWinner result = _determineWinner(games[_gameId].player1.move, games[_gameId].player2.move);
            games[_gameId].result = result;
            _updateWinings(player1, player2, result, games[_gameId].wager);
            emit GameResult(_gameId, result);
        }
    }

    
    // Add this function to your RockPaperScissors contract
    function _determineWinner(Move player1Move, Move player2Move) internal pure returns (GameWinner result) {
        if (player1Move == player2Move) {
            result = GameWinner.Draw;
        } else if ((player1Move == Move.Rock && player2Move == Move.Scissors) ||
                   (player1Move == Move.Scissors && player2Move == Move.Paper) ||
                   (player1Move == Move.Paper && player2Move == Move.Rock)) {
            result = GameWinner.Player1;
            
        } else {
            result = GameWinner.Player2;
        }
    }

    // Update leaderboard counter for leaderboard and send funds
    function _updateWinings(address player1, address player2, GameWinner result, uint _wagerAmount) internal {
        if (result == GameWinner.Player1) { 
            ++consecutiveWins[player1];
            consecutiveWins[player2] = 0;
            paymentToken.safeTransfer(player1, 2*_wagerAmount);
            _checkAndAwardJackpot(player1);
        } else if(result == GameWinner.Player2) {
            consecutiveWins[player1] = 0;
            ++consecutiveWins[player2];
            paymentToken.safeTransfer(player2, 2*_wagerAmount);
            _checkAndAwardJackpot(player1);
        } else {
            paymentToken.safeTransfer(player1, _wagerAmount);
            paymentToken.safeTransfer(player2, _wagerAmount);
        }
    }

    // Award a jackpot
    function _checkAndAwardJackpot(address _player) internal {
        if (consecutiveWins[_player] >= minConsecutiveWins && collectedAmount >= minJackpotAmount) {
            paymentToken.safeTransfer(_player, minJackpotAmount);
            emit JackpotWon(_player, minJackpotAmount);
            collectedAmount -= minJackpotAmount; 
        }
    }
    
}