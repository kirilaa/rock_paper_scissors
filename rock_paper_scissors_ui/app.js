

const contractAddress = "0x27146E4f55560eF3c829b52055fe1bf688f10D03";
const paymentTokenAddress = "0x5ab559c06339D8E068De83afAB372834e7d060Db";


let abi;
let paymentAbi;


fetch('./RockPaperScissorsABI.json')
    .then(response => response.json())
    .then(data => {
        abi = data;
        fetch('./PaymentTokenABI.json')
        .then(response => response.json())
        .then(data => {
            paymentAbi = data;

        main();
        })
    })
    .catch(error => console.error("Failed to load ABI", error));

    



async function main() {
    if (window.ethereum) {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        const signer = provider.getSigner();
        const gameContract = new ethers.Contract(contractAddress, abi, signer); 
        const paymentTokenContract = new ethers.Contract(paymentTokenAddress, paymentAbi, signer);


        document.getElementById('rock').addEventListener('click', () => playMove('Rock'));
        document.getElementById('paper').addEventListener('click', () => playMove('Paper'));
        document.getElementById('scissors').addEventListener('click', () => playMove('Scissors'));

        async function playMove(move) {
            // Generate a random nonce for each move
            const nonce = document.getElementById('move-nonce').value.trim();

            // Check if the nonce is empty
            if (!nonce) {
                updateStatus('Please enter a unique nonce before playing your move.');
                return;
            }
            
            // Combine the move and nonce to create a unique hash
            const moveEnum = { 'Rock': 1, 'Paper': 2, 'Scissors': 3 }[move];
            const moveHash = await gameContract.hashMove(moveEnum, nonce);
            updateStatus(`You played ${move}. Move committed with nonce: ${nonce}.`);
            // const moveHash = ethers.utils.solidityKeccak256(["uint8", "bytes32"], [moveEnum, nonce]);
            // Store the move and nonce in the local storage or another secure place
            localStorage.setItem('committedMove', move);
            localStorage.setItem('nonce', nonce);
            // Send the moveHash to the smart contract
            try {
                const tx = await gameContract.commitMove(moveHash);
                await tx.wait(); // Wait for the transaction to be mined
                await updateBalance();
            } catch (error) {
                updateStatus(`Error: ${error.message}`);
            }
        }
        async function revealMove(move, nonce) {
            try {
                console.log("Here");
                console.log("Move: ", move);
                console.log("Nonce: ", nonce);
                // Convert the move to enum format as expected by the smart contract
                const moveEnum = move === 'Rock' ? 1 : move === 'Paper' ? 2 : 3;
                // Call the revealMove method from your smart contract
                const tx = await gameContract.revealMoveForLastGame(moveEnum, nonce);
                await tx.wait(); // Wait for the transaction to be mined
                updateStatus(`Move ${move} revealed with nonce ${nonce}.`);
                await updateBalance();
                await updateWinner();
                await updateLeaderboard();
            } catch (error) {
                updateStatus(`Error during reveal: ${error.message}`);
            }
        }

        function updateStatus(status) {
            document.getElementById('status').innerText = status;
        }
        

        document.getElementById('mint').addEventListener('click', async () => {
            try {
                const tx = await paymentTokenContract.mint(signer.getAddress(), ethers.utils.parseEther("1000"));
                await tx.wait();
                updateStatus('Minted 1000 tokens successfully.');
                await updateBalance();
            } catch (error) {
                updateStatus(`Error during minting: ${error.message}`);
            }
        });
    
        document.getElementById('approve').addEventListener('click', async () => {
            try {
                const tx = await paymentTokenContract.approve(contractAddress, ethers.utils.parseEther("1000"));
                await tx.wait();
                updateStatus('Approved RockPaperScissors contract to use 1000 tokens successfully.');
            } catch (error) {
                updateStatus(`Error  during approval: ${error.message}`);
            }
        });

        document.getElementById('reveal').addEventListener('click', async () => {
            // Retrieve the move from the selected radio button
            let move;
            const radios = document.getElementsByName('move');
            for (let i = 0, length = radios.length; i < length; i++) {
                if (radios[i].checked) {
                    move = radios[i].value;
                    break;
                }
            }
        
            // Retrieve the nonce from the input field
            const nonce = document.getElementById('nonce').value;
        
            // Check if the move and nonce are available
            if (!move || !nonce) {
                updateStatus('Please select your move and enter your nonce.');
                return;
            }
        
            await revealMove(move, nonce);
        });
        
        async function updateBalance() {
            const balance = await paymentTokenContract.balanceOf(signer.getAddress());
            document.getElementById('balance').innerText = `Balance: ${ethers.utils.formatEther(balance)}`;
        }
        
        async function updateWinner() {
            const gameCounter = await gameContract.gameCounter();
            const winner = await gameContract.getWinner(gameCounter);
            console.log("Winner: ", winner)
            document.getElementById('winner').innerText = `Winner: ${winner}`;
        }

        async function updateLeaderboard() {
            const leaderboard = await getLeaderboard(); 
            const tbody = document.getElementById('leaderboard').getElementsByTagName('tbody')[0];
            tbody.innerHTML = ''; 
        
            // Add each player to the leaderboard
            for (const player of leaderboard) {
                const row = tbody.insertRow();
                const addressCell = row.insertCell();
                const winsCell = row.insertCell();
                addressCell.textContent = player.address;
                winsCell.textContent = player.wins;
            }
        }

        async function getLeaderboard() {
            const leaderboardData = await gameContract.getLeaderboard();
            const leaderboard = leaderboardData.map((playerData, index) => {
                return {
                    address: playerData[0],
                    wins: playerData[1].toNumber() 
                };
            });
        
            return leaderboard;
        }

        

       
    } else {
        console.error("Please install MetaMask!");
    }
}



main().catch(console.error);