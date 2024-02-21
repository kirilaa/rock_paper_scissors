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
    string nonce1 = "secret1";
    string nonce2 = "secret2";
    PaymentToken paymentToken;
    uint wagerAmount = 100;
    uint feePercentage = 1;
    uint consecutiveWins = 3;

    function setUp() public {
        paymentToken = new PaymentToken(10000);
        paymentToken.mint(player1, 1000);
        paymentToken.mint(player2, 1000);
        game = new RockPaperScissors(address(paymentToken), wagerAmount, feePercentage, consecutiveWins);
    }
    
    function testCommitMoveWithWager() public {
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

    // function testRevealMoveForLastGame() public {
    //     testCommitMoveWithWager();
    //     game.startRevealPhase();

    //     vm.startPrank(player1);
    //     game.revealMoveForLastGame(RockPaperScissors.Move.Scissors, nonce1);
    //     vm.stopPrank();
    //     ( , , RockPaperScissors.Move move, ) = game.player1();
    //     assertEq(uint(move), uint(RockPaperScissors.Move.Scissors), "Player 1 reveal failed");

    //     vm.startPrank(player2);
    //     game.revealMoveForLastGame(RockPaperScissors.Move.Paper, nonce2);
    //     vm.stopPrank();
    //     ( , ,  move, ) = game.player2();
    //     assertEq(uint(move), uint(RockPaperScissors.Move.Paper), "Player 2 reveal failed");
    // }

    // function testDetermineWinner() public {
    //     testRevealMoveForLastGame();
    //     RockPaperScissors.GameWinner winner = game._determineWinner(RockPaperScissors.Move.Scissors, RockPaperScissors.Move.Paper);
    //     assertEq(uint(winner), uint(RockPaperScissors.GameWinner.Player2), "Winner determination failed");
    // }

    // function testHashMove() public {
    //     bytes32 hashedMove = game.hashMove(RockPaperScissors.Move.Scissors, nonce1);
    //     bytes32 expectedHash = keccak256(abi.encodePacked(RockPaperScissors.Move.Scissors, nonce1));
    //     assertEq(hashedMove, expectedHash, "Hash move failed");
    // }
}