import { ethers } from "hardhat";

/**
 * The code calculates the current timestamp in seconds since epoch,
 * defines an unlock time 60 seconds in the future, and deploys a new
 * instance of a smart contract called Lock with a locked amount of
 * 0.001 ETH and an unlock time of 60 seconds in the future. The 
 * contract address is logged to the console. If any errors occur, they
 * are logged to the console and the process exit code is set to 1.
 */
async function main() {
  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  // Calculate the current timestamps in seconds since epoch (Unix time) and round it to the nearest second.
  
  const unlockTime = currentTimestampInSeconds + 60;
  // Define the unlock time to be 60 seconds after the current timestamp

  const lockedAmount = ethers.utils.parseEther("0.001");
  // Parse a string representing 0.001 ETH as a BigNumber and store it in lockedAmount

  const Lock = await ethers.getContractFactory("Lock");
  // Get the Lock contract factory from ethers and store it in Lock

  const lock = await Lock.deploy(unlockTime, { value: lockedAmount });
  // Deploy a new instance of the Lock contract, passing in the unlock time and the locked amount as options

  await lock.deployed();
  // Wait for the contract deployment transaction to be confirmed

  console.log(
    // Log a message to the console indicating that the contract has been deployed, including the locked amount, unlock time, and contract address
    `Lock with ${ethers.utils.formatEther(lockedAmount)}ETH and unlock timestamp ${unlockTime} deployed to ${lock.address}`
  );
}

// Call the main function and handle any errors that occur
// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
