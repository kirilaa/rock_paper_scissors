const hre = require("hardhat");
var fs = require('fs');

async function main() {
  // Fetch the compiled contract using its name
  const RockPaperScissors = await hre.ethers.getContractFactory("RockPaperScissors");
  const PaymentToken = await hre.ethers.getContractFactory("PaymentToken");
  const totalSupply = "10000000000000000000000";
  const wagerAmount = "100000000000000000000";
  const feeAmount = "10";
  const minConsecutiveWins = "3";
  const minJackpotAmount = "1000000000000000000000";
  const paymentToken = await PaymentToken.deploy(totalSupply);
  await paymentToken.deployed();

  console.log("PaymentToken deployed to:", paymentToken.address);

  // Deploy the contract with constructor arguments
  const rockPaperScissors = await RockPaperScissors.deploy(paymentToken.address, wagerAmount, feeAmount, minConsecutiveWins, minJackpotAmount);

  // Wait for the deployment to finish
  await rockPaperScissors.deployed();

  const deployments = {deployments: []};
  deployments.deployments.push({paymentToken: paymentToken.address, rockPaperScissors: rockPaperScissors.address });
  const json = JSON.stringify(deployments);
  fs.writeFile('./script/deploymentsOnGoerli.json', json, 'utf8', () => {});

  console.log("RockPaperScissors deployed to:", rockPaperScissors.address);
  // Verify the contract on Etherscan
  try {
    await hre.run("verify:verify", {
      address: rockPaperScissors.address,
      constructorArguments: [paymentToken.address, wagerAmount, feeAmount, minConsecutiveWins, minJackpotAmount],
    });
    console.log("Contract verified on Etherscan");
  } catch (error) {
    console.error("Failed to verify contract on Etherscan:", error);
  }
  
  try {
    await hre.run("verify:verify", {
      address: paymentToken.address,
      constructorArguments: [totalSupply],
    });
    console.log("Contract verified on Etherscan");
  } catch (error) {
    console.error("Failed to verify contract on Etherscan:", error);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });