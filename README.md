# Rock Paper Scissors game 

Contains 2 folders:  
*rock_paper_scissors* : the smart contracts behind the game (done in Foundry, deployed on Goerli with hardhat)  
*rock_paper_scissors_ui* : the attempt for an UI

## The Game logic
1. Game Setup: The contract is initialized with a payment token, wager amount, fee amount, minimum consecutive wins, and minimum jackpot amount. The payment token is an ERC20 token used for wagers. The wager amount is the amount a player must bet to play a game. The fee amount is a percentage of the wager that is taken as a fee. The minimum consecutive wins is the number of games a player must win in a row to win the jackpot. The minimum jackpot amount is the minimum amount that the jackpot can be.
2. Committing a Move: A player commits a move by calling the `commitMove()` function with a hash of their move and a nonce. The player must have enough of the payment token to cover the wager and must have approved the contract to spend that amount. The move is stored in a Game struct, and the state of the game is updated. The wager amount is transferred from the player to the contract, and a fee is taken.
3. Revealing a Move: A player reveals their move by calling the `revealMoveForGame()` or `revealMoveForLastGame()` function with their move and the nonce they used to hash it. The move is checked against the hash they committed earlier. If the game is in the correct state and the hash matches, the move is stored in the Game struct, and the state of the game is updated.
4. Determining the Winner: Once both players have revealed their moves, the `_determineWinner()` function is called to determine the winner based on the rules of Rock, Paper, Scissors. The result is stored in the Game struct.
5. Updating Winnings: The `_updateWinings()` function is called to update the consecutive wins of the players and transfer the winnings to the winner. If the game was a draw, the wager is returned to both players. If a player has won the minimum number of consecutive games and the jackpot is large enough, they win the jackpot.
6. Leaderboard: The contract keeps track of all players and their number of consecutive wins. The `getLeaderboard()` function can be called to get a sorted list of players and their win counts.
7. Game Information: The contract provides several functions to get information about a game, including the moves committed and revealed by the players, the state of the game, and the result.

## The UI
1. Minting Tokens: The UI has a 'Mint' button. When this button is clicked, the mint function is called, which mints 1000 tokens to the user's address.
2. Approving Tokens: The UI has an 'Approve' button. When this button is clicked, the approve function is called, which approves the RockPaperScissors contract to spend 1000 tokens from the user's address.
3. Make Move: The UI has buttons for the moves 'Rock', 'Paper', and 'Scissors'. When a button is clicked, the playMove function is called with the corresponding move. This function generates a hash of the move and a nonce, stores the move and nonce in local storage, and sends the hash to the smart contract.
4. Revealing a Move: The UI has a 'Reveal' button. When this button is clicked, the revealMove function is called with the move and nonce from the input fields. This function sends the move and nonce to the smart contract to reveal the move.
5. Displaying Status: The UI has a status field that displays messages to the user. The updateStatus function is used to update this field.
6. Displaying Balance: The UI has a balance field that displays the user's token balance.
7. (*disclaimer: not working*) Displaying Winner: The UI has a winner field that displays the winner of the last game. The updateWinner function is used to update this field.
8. (*disclaimer: not working*) Displaying Leaderboard: The UI has a leaderboard table that displays the addresses of players and their number of wins.


## Different Mode to Play
Additional mode to play would have been only counter the smart contract
1. The user makes move in a same manner
2. The contract receives the move and obtains a random number from an oracle. The random number is used for generating a move. Both moves are stored simultaneously.
3. The user reveals its move and the winner is decided simultaneously.
4. The funds of the contract can be feed through Liquidity Pools (LPs)
