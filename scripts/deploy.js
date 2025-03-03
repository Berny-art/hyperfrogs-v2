// scripts/deploy.js
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Provided testnet addresses
  const hyperFrogsAddress = "0x5bB638Ea28314116514daa924310E9575C3a78f8";    // Old HyperFrogs
  const frogsBackdropAddress = "0x8D2489ff3c82A92BC2b2F6c717eE7316cDb13Ea4";   // FrogsBackdrop
  const frogsOneOfOneAddress = "0x68160933deB55de5291dbd18016E20C18350113E";    // FrogsOneOfOne
  const frogsBodyAddress = "0xc9dadCce15688ac392C905bdE6ad715C9A7482F9";       // FrogsBody
  const frogsHatsAddress = "0x4ecB787d14E419643818B8aD5477E86f2D00d449";        // FrogsHats
  const frogsEyesAAddress = "0xdD541b89d4c89fe351828F698660F04deE6D6a93";       // FrogsEyesA
  const frogsEyesBAddress = "0x3A95FB432520d7AB9d136958e96915479F7284Bb";       // FrogsEyesB
  const frogsMouthAddress = "0x8582aACeD82Ae034Eeb05F869d843634450dB428";       // FrogsMouth
  const frogsFeetAddress = "0xF315bc82CF65EC3c4e77d57F84CfF1473652aFa4";         // FrogsFeet

  // Get the contract factory for HyperFrogsV2
  const HyperFrogsV2 = await ethers.getContractFactory("HyperFrogsV2");

  // Deploy the contract, passing parameters in the correct order:
  // (_oldContract, _frogsBackdrop, _frogsOneOfOne, _frogsBody, _frogsHats, _frogsEyesA, _frogsEyesB, _frogsMouth, _frogsFeet)
  const hyperFrogsV2 = await HyperFrogsV2.deploy(
    hyperFrogsAddress,
    frogsBackdropAddress,
    frogsOneOfOneAddress,
    frogsBodyAddress,
    frogsHatsAddress,
    frogsEyesAAddress,
    frogsEyesBAddress,
    frogsMouthAddress,
    frogsFeetAddress
  );

  // Wait for deployment to be mined
  await hyperFrogsV2.waitForDeployment();

  console.log("HyperFrogsV2 deployed to:", hyperFrogsV2.target);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });
