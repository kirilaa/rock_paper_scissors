// app.js
// const fs = require('fs');
// import ethers from 'ethers';
const contractAddress = "0x45eA71bed985F3d5E8a40Ad1c0662b15B3f23059";
const paymentTokenAddress = "0x4876a60608e3BFF458D37307501c993e3ae6d694";
// const abi = JSON.parse(fs.readFileSync('./RockPaperScissorsABI.json', 'utf8'));

let abi;
let paymentAbi;

// Use fetch API to load the ABI from a JSON file
fetch('./RockPaperScissorsABI.json')
    .then(response => response.json())
    .then(data => {
        abi = data;
        fetch('./PaymentTokenABI.json')
        .then(response => response.json())
        .then(data => {
            paymentAbi = data;
        // Initialize the app after the ABI is loaded
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
            updateStatus(`You played ${move}. Move committed with nonce: ${nonce}. Waiting for the reveal...`);
            // const moveHash = ethers.utils.solidityKeccak256(["uint8", "bytes32"], [moveEnum, nonce]);
            // Store the move and nonce in the local storage or another secure place
            localStorage.setItem('committedMove', move);
            localStorage.setItem('nonce', nonce);
            // Send the moveHash to the smart contract
            try {
                const tx = await gameContract.commitMove(moveHash);
                await tx.wait(); // Wait for the transaction to be mined
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
            } catch (error) {
                updateStatus(`Error during reveal: ${error.message}`);
            }
        }

        function updateStatus(status) {
            document.getElementById('status').innerText = status;
        }
        
        document.getElementById('reveal').addEventListener('click', async () => {
            // Retrieve the move from where you have securely stored it
            const committedMove = localStorage.getItem('committedMove');
            // Retrieve the nonce from the input field
            const nonce = document.getElementById('nonce').value;
        
            // Check if the move and nonce are available
            if (!committedMove || !nonce) {
                updateStatus('Please enter your nonce and make sure you have committed a move.');
                return;
            }
        
            await revealMove(committedMove, nonce);
        });

        document.getElementById('mint').addEventListener('click', async () => {
            try {
                const tx = await paymentTokenContract.mint(signer.getAddress(), ethers.utils.parseEther("1000"));
                await tx.wait();
                updateStatus('Minted 1000 tokens successfully.');
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

       
    } else {
        console.error("Please install MetaMask!");
    }
}



main().catch(console.error);