// scripts/claim.js
const { ethers } = require("hardhat");

async function main() {
	// Get tokenId from command line arguments
	const tokenId = 6;
	
	// Check if tokenId is provided
	if (!tokenId) {
		console.error("Please provide a tokenId as an argument. Example: npx hardhat run scripts/claim.js --network mainnet 3");
		process.exit(1);
	}
	
	// Deployed addresses
	const migrationContractAddress = "0xC53d409649B7557824c5E6453229d89A6da1a9E0";
	const oldContractAddress = "0x5bB638Ea28314116514daa924310E9575C3a78f8";

	// Get signer (the account attempting the claim)
	const [signer] = await ethers.getSigners();
	console.log(`Claiming token ID ${tokenId} with account:`, signer.address);

	// Get the migration contract instance
	const hyperFrogsV2 = await ethers.getContractAt(
		"HyperFrogsV2",
		migrationContractAddress,
		signer,
	);

	// Get an instance of the old contract using IHyperFrogs interface
	const oldHyperFrogs = await ethers.getContractAt(
		"IHyperFrogs",
		oldContractAddress,
		signer,
	);

	// Log the owner of the specified token from the old contract
	const ownerOfToken = await oldHyperFrogs.ownerOf(tokenId);
	console.log(`Owner of token ID ${tokenId} in old contract:`, ownerOfToken);

	const storedOldContractAddress = await hyperFrogsV2.oldContract();
	console.log("Stored oldContract address:", storedOldContractAddress);

	// Check if the signer is indeed the owner
	if (ownerOfToken.toLowerCase() !== signer.address.toLowerCase()) {
		console.error(
			`Signer does not own token ID ${tokenId} in the old contract. Aborting claim.`,
		);
		return;
	}

	// Approve the migration contract to manage tokens in the old contract (if needed)
	const oldERC721 = await ethers.getContractAt(
		"IERC721",
		oldContractAddress,
		signer,
	);
	console.log(
		"Setting approval for all tokens on the old contract to the migration contract...",
	);
	let tx = await oldERC721.setApprovalForAll(migrationContractAddress, true);
	await tx.wait();
	console.log("Approval granted.");

	// Attempt to claim the specified token ID
	console.log(`Attempting to claim token ID ${tokenId}...`);
	try {
		tx = await hyperFrogsV2.batchClaim([tokenId], { gasLimit: 2000000 });
		await tx.wait();
		console.log(`Token ID ${tokenId} successfully claimed.`);
	} catch (error) {
		console.error(`Error claiming token ID ${tokenId}:`, error);
	}
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error("Script execution failed:", error);
		process.exit(1);
	});

    //