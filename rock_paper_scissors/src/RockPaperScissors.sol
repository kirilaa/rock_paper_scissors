// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RockPaperScissors {
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

    error InvalidGameState(GameState _state);

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



    // Events
    event MoveCommitted(address player, uint gameId, uint wager, uint fee);
    event JackpotWon(address winner, uint amount);
    event GameResult(uint _gameId, GameWinner _winner);

    constructor(address _paymentToken, uint _wagerAmount, uint _feeAmount, uint _minConsecutiveWins) {
        paymentToken = IERC20(_paymentToken);
        if(_wagerAmount == 0 ) _wagerAmount = MIN_WAGER_AMOUNT; 
        wagerAmount = _wagerAmount;
        if(_feeAmount > 99) {
            feePercentage = 99;
        } else {
            feePercentage = _feeAmount;
        }
        minJackpotAmount = 100*wagerAmount;
        minConsecutiveWins = _minConsecutiveWins;
    }

    function getGameInfo(uint _gameId) public view returns(Game memory) {
        return games[_gameId];
    }

    function getPlayerInfoForGame(uint _gameId, uint _playerIndex) public view returns(Player memory) {
        if(_playerIndex == 0) {
            return games[_gameId].player1;
        } else {
            return games[_gameId].player2;
        }
    }

    function getLeaderboard() public view returns (address[] memory leaderboard, uint[] memory wins) {
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


    function commitMove(bytes32 _moveHash) public {
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

    
    
    function _commitMove(bytes32 _moveHash) internal returns (uint){
        
        uint lastGameId;
        if(gameCounter > 0 && games[gameCounter].state < GameState.Player2Commited) {
            lastGameId = gameCounter;
        } else {
            lastGameId = ++gameCounter;
        }
        
        address player1 = games[lastGameId].player1.addr;
        address player2 = games[lastGameId].player2.addr;
        require(playerLastGame[msg.sender] != lastGameId, "Already played" );
        require(player1 != msg.sender || player2 != msg.sender, "Player already played" );

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

    function hashMove(Move _move, string memory _nonce) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(_move, _nonce));
    }

    function revealMoveForLastGame(Move _move, string memory _nonce) external  {
        require(playerLastGame[msg.sender] != 0, "No game to reveal");
        GameState gameState = games[playerLastGame[msg.sender]].state;
        address player1 = games[playerLastGame[msg.sender]].player1.addr;
        address player2 = games[playerLastGame[msg.sender]].player2.addr;
        require(player1 == msg.sender || player2 == msg.sender, "Not in reveal phase");
        require(_move != Move.None, "Invalid move");
        uint gameId = playerLastGame[msg.sender];
        bytes32 moveHash = keccak256(abi.encodePacked(_move, _nonce));

        if (msg.sender == games[gameId].player1.addr) {
            require(moveHash == games[gameId].player1.moveHash, "Hash mismatch");
            games[gameId].player1.move = _move;
        } else {
            require(moveHash == games[gameId].player2.moveHash, "Hash mismatch");
            games[gameId].player2.move = _move;
        }
        if(gameState == GameState.Player2Commited) {
            games[gameId].state = GameState.OnePlayerRevealed;
        }
        else {
            games[gameId].state = GameState.WinnerAnnounced;
            GameWinner result = _determineWinner(games[gameId].player1.move, games[gameId].player2.move);
            games[gameId].result = result;
            _updateWinings(games[gameId].player1.addr, games[gameId].player2.addr, result, games[gameId].wager);
            emit GameResult(gameId, result);
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

    function _updateWinings(address player1, address player2, GameWinner result, uint _wagerAmount) internal {
        if (result == GameWinner.Player1) { 
            ++consecutiveWins[player1];
            consecutiveWins[player2] = 0;
            paymentToken.safeTransfer(player1, 2*_wagerAmount);
        } else if(result == GameWinner.Player2) {
            consecutiveWins[player1] = 0;
            ++consecutiveWins[player2];
            paymentToken.safeTransfer(player2, 2*_wagerAmount);
        } else {
            paymentToken.safeTransfer(player1, _wagerAmount);
            paymentToken.safeTransfer(player2, _wagerAmount);
        }
    }

    function _checkAndAwardJackpot(address _player) internal {
        if (consecutiveWins[_player] >= minConsecutiveWins && collectedAmount >= minJackpotAmount) { // Assuming 3 wins for a jackpot
            paymentToken.safeTransfer(_player, minJackpotAmount);
            emit JackpotWon(_player, minJackpotAmount);
            collectedAmount -= minJackpotAmount; 
        }
    }
    
}