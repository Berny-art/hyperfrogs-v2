// scripts/deploy.js
const hre = require("hardhat");

async function main() {
  // Get the deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Set the addresses for required contracts.
  // Replace these placeholder addresses with your actual deployed contract addresses.
  const oldContractAddress = "0xOldContractAddress";             // Old HyperFrogs contract
  const frogsBackdropAddress = "0xFrogsBackdropAddress";           // FrogsBackdrop contract
  const frogsOneOfOneAddress = "0xFrogsOneOfOneAddress";           // FrogsOneOfOne contract
  const frogsBodyAddress = "0xFrogsBodyAddress";                   // FrogsBody contract
  const frogsHatsAddress = "0xFrogsHatsAddress";                   // FrogsHats contract
  const frogsEyesAAddress = "0xFrogsEyesAAddress";                 // FrogsEyesA contract
  const frogsEyesBAddress = "0xFrogsEyesBAddress";                 // FrogsEyesB contract
  const frogsMouthAddress = "0xFrogsMouthAddress";                 // FrogsMouth contract
  const frogsFeetAddress = "0xFrogsFeetAddress";                   // FrogsFeet contract

  // Get the contract factory for HyperFrogsV2
  const HyperFrogsV2 = await hre.ethers.getContractFactory("HyperFrogsV2");

  // Deploy the contract with the required parameters
  const hyperFrogsV2 = await HyperFrogsV2.deploy(
    oldContractAddress,
    frogsBackdropAddress,
    frogsOneOfOneAddress,
    frogsBodyAddress,
    frogsHatsAddress,
    frogsEyesAAddress,
    frogsEyesBAddress,
    frogsMouthAddress,
    frogsFeetAddress
  );

  await hyperFrogsV2.deployed();

  console.log("HyperFrogsV2 deployed to:", hyperFrogsV2.address);
}

// Run the main function and catch errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });
