// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {RockPaperScissors} from "../src/RockPaperScissors.sol";
import {PaymentToken} from "../src/PaymentToken.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/console.sol";


contract RockPaperScissorsTest is Test {

    RockPaperScissors game;
    address player1 = address(1);
    address player2 = address(2);
    address player3 = address(3);
    address player4 = address(4);
    string nonce1 = "secret1";
    string nonce2 = "secret2";
    string nonce3 = "secret3";
    string nonce4 = "secret4";
    PaymentToken paymentToken;
    uint wagerAmount = 100;
    uint feePercentage = 50;
    uint consecutiveWins = 2;
    uint minJackpotAmount = 100;

    address[] allPlayers = [player1, player2, player3, player4];
    string[] nonces = [nonce1, nonce2, nonce3, nonce4];

    function setUp() public {
        paymentToken = new PaymentToken(10000);
        paymentToken.mint(player1, 1000);
        paymentToken.mint(player2, 1000);
        paymentToken.mint(player3, 1000);
        paymentToken.mint(player4, 1000);
        game = new RockPaperScissors(address(paymentToken), wagerAmount, feePercentage, consecutiveWins, minJackpotAmount);
    }
    
    function testCommitMove() public {
        uint initialBalancePlayer1 = paymentToken.balanceOf(player1);
        uint initialBalanceContract = paymentToken.balanceOf(address(game));
        uint wager = game.wagerAmount();
        uint fee = (wager * game.feePercentage()) / 100;
        uint netWager = wager - fee;

        bytes32 commit1 = keccak256(abi.encodePacked(RockPaperScissors.Move.Scissors, nonce1));
        vm.prank(player1);
        paymentToken.approve(address(game), wager);
        vm.startPrank(player1);
        game.commitMove(commit1);
        vm.stopPrank();

        uint finalBalancePlayer1 = paymentToken.balanceOf(player1);
        uint finalBalanceContract = paymentToken.balanceOf(address(game));

        assertEq(initialBalancePlayer1 - finalBalancePlayer1, wager, "Wager not deducted from player 1");
        assertEq(finalBalanceContract - initialBalanceContract, wager, "Wager not received by contract");
        uint gameId = game.gameCounter();
        assertEq(gameId, 1, "Game is not 1");
        assertEq(game.getGameInfo(gameId).player1.moveHash, commit1, "Player 1 commit with wager failed");
        assertEq(game.getGameInfo(gameId).wager, netWager, "Player 1 wager with fee failed");
    }

    function testRevealMoveForLastGame() public {
        // Player 1 commits a move
        bytes32 commit1 = keccak256(abi.encodePacked(RockPaperScissors.Move.Scissors, nonce1));
        vm.prank(player1);
        paymentToken.approve(address(game), wagerAmount);
        vm.startPrank(player1);
        game.commitMove(commit1);
        vm.stopPrank();
       
        // Player 2 commits a move
        bytes32 commit2 = keccak256(abi.encodePacked(RockPaperScissors.Move.Paper, nonce2));
        vm.prank(player2);
        paymentToken.approve(address(game), wagerAmount);
        vm.startPrank(player2);
        game.commitMove(commit2);
        vm.stopPrank();

        uint gameId = game.gameCounter();

        // Player 1 reveals move
        vm.startPrank(player1);
        game.revealMoveForLastGame(RockPaperScissors.Move.Scissors, nonce1);
        vm.stopPrank();
        RockPaperScissors.Move move1 = game.getGameInfo(gameId).player1.move;
        assertEq(uint(move1), uint(RockPaperScissors.Move.Scissors), "Player 1 reveal failed");

        // Player 2 reveals move
        vm.startPrank(player2);
        game.revealMoveForLastGame(RockPaperScissors.Move.Paper, nonce2);
        vm.stopPrank();
        RockPaperScissors.Move move2 = game.getGameInfo(gameId).player2.move;
        assertEq(uint(move2), uint(RockPaperScissors.Move.Paper), "Player 2 reveal failed");

        // // Determine the winner
        RockPaperScissors.GameWinner winner = game.getGameInfo(gameId).result;
        assertEq(uint(winner), uint(RockPaperScissors.GameWinner.Player1), "Winner determination failed");

        // Winner event
        (bool success, bytes memory data) = address(game).call(abi.encodeWithSignature("getGameInfo(uint256)", gameId));
        require(success, "getGameInfo call failed");
        ( , , , RockPaperScissors.GameWinner eventWinner, ) = abi.decode(data, (RockPaperScissors.GameState, RockPaperScissors.Player, RockPaperScissors.Player, RockPaperScissors.GameWinner, uint));
        assertEq(uint(eventWinner), uint(winner), "Winner event failed");
    }
    
    function testDoubleCommitMove() public {

        // Player 1 commits a move
        bytes32 commit1 = keccak256(abi.encodePacked(RockPaperScissors.Move.Scissors, nonce1));
        vm.prank(player1);
        paymentToken.approve(address(game), 1000000);
        vm.startPrank(player1);
        game.commitMove(commit1);
        vm.stopPrank();

        uint gameId = game.gameCounter();

        vm.prank(player1);
        paymentToken.approve(address(game), 1000000);
        vm.startPrank(player1);
        // Player 1 tries to commit a move again
        bytes32 commit2 = keccak256(abi.encodePacked(RockPaperScissors.Move.Rock, nonce1));
        bool success;
        string memory reason;
        try game.commitMove(commit2) {
            success = true;
        } catch Error(string memory _reason) {
            success = false;
            reason = _reason;
        } catch {
            success = false;
        }
        vm.stopPrank();
        console.log(reason);
        require(!success, "Player 1 was able to commit a move twice");
        assertEq(reason, "Already played", "Player 1 was able to commit a move twice with wrong reason");
        uint player1LastGame = game.playerLastGame(player1);
        assertEq(player1LastGame, gameId, "Player 1 last game is not the current game");
    }

    function testMultiplePlayersAndLeaderboard() public {
        RockPaperScissors.Move[3] memory moves = [ RockPaperScissors.Move.Rock, RockPaperScissors.Move.Paper, RockPaperScissors.Move.Scissors];
        for(uint i=0; i<allPlayers.length; i++) {
            bytes32 commit = keccak256(abi.encodePacked(moves[i%3], nonces[i]));
            vm.prank(allPlayers[i]);
            paymentToken.approve(address(game), wagerAmount);
            vm.startPrank(allPlayers[i]);
            game.commitMove(commit);
            vm.stopPrank();
        }
        RockPaperScissors.Move move;
        string memory nonce;
        for(uint i=0; i<allPlayers.length; i++) {
            move = moves[i%3];
            nonce = nonces[i];
            vm.prank(allPlayers[i]);
            game.revealMoveForLastGame(move, nonce);
            vm.stopPrank();
        }
       
        // Display leaderboard
        (address[] memory leaderboard, uint[] memory wins) = game.getLeaderboard();
        for (uint i = 0; i < leaderboard.length; i++) {
            console.log("Player: ", leaderboard[i], " Wins: ", wins[i]);
        }
    }

    function testJackpotWon() public {
        uint jackpotBefore;
        for(uint i=0; i<consecutiveWins; i++) {
            // Player 1 commits a move
            bytes32 commit1 = keccak256(abi.encodePacked(RockPaperScissors.Move.Scissors, nonce1));
            vm.prank(player1);
            paymentToken.approve(address(game), 1000000);
            vm.startPrank(player1);
            game.commitMove(commit1);
            vm.stopPrank();
            uint gameId = game.gameCounter();
            // Player 2 commits a move
            bytes32 commit2 = keccak256(abi.encodePacked(RockPaperScissors.Move.Paper, nonce2));
            vm.prank(player2);
            paymentToken.approve(address(game), wagerAmount);
            vm.startPrank(player2);
            game.commitMove(commit2);
            vm.stopPrank();
            if(i+1== consecutiveWins) {
                jackpotBefore = game.collectedAmount();
            }
            // Player 1 reveals move
            vm.startPrank(player1);
            game.revealMoveForLastGame(RockPaperScissors.Move.Scissors, nonce1);
            vm.stopPrank();
            RockPaperScissors.Move move1 = game.getGameInfo(gameId).player1.move;
            // Player 2 reveals move
            vm.startPrank(player2);
            game.revealMoveForLastGame(RockPaperScissors.Move.Paper, nonce2);
            vm.stopPrank();
            RockPaperScissors.Move move2 = game.getGameInfo(gameId).player2.move;
        }
        console.log("Jackpot before: ", jackpotBefore);
        uint jackpotAfter = game.collectedAmount();
        console.log("Jackpot after: ", jackpotAfter);
        assertEq(jackpotBefore - jackpotAfter, minJackpotAmount, "Jackpot amount not correctly transferred");
    }
    
}