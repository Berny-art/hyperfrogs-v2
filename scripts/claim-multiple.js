const { ethers } = require("hardhat");

async function main() {
	// Define multiple token IDs (from env or hardcoded)
	const tokenIds = [0,2223]

	if (tokenIds.length === 0) {
		console.error("Please provide token IDs. Example: TOKEN_IDS=6,12,34 npx hardhat run scripts/claim.js --network mainnet");
		process.exit(1);
	}

	// Deployed addresses
	const migrationContractAddress = "0xC53d409649B7557824c5E6453229d89A6da1a9E0";
	const oldContractAddress = "0x5bB638Ea28314116514daa924310E9575C3a78f8";

	const [signer] = await ethers.getSigners();
	console.log(`Claiming tokens [${tokenIds.join(", ")}] with account: ${signer.address}`);

	const hyperFrogsV2 = await ethers.getContractAt("HyperFrogsV2", migrationContractAddress, signer);
	const oldHyperFrogs = await ethers.getContractAt("IHyperFrogs", oldContractAddress, signer);
	const oldERC721 = await ethers.getContractAt("IERC721", oldContractAddress, signer);

	const storedOldContractAddress = await hyperFrogsV2.oldContract();
	console.log("Stored oldContract address:", storedOldContractAddress);

	// Validate ownership
	const validTokenIds = [];
	for (const tokenId of tokenIds) {
		try {
			const ownerOfToken = await oldHyperFrogs.ownerOf(tokenId);
			console.log(`Owner of token ID ${tokenId} in old contract: ${ownerOfToken}`);
			if (ownerOfToken.toLowerCase() === signer.address.toLowerCase()) {
				validTokenIds.push(tokenId);
			} else {
				console.warn(`Skipping token ID ${tokenId}: not owned by signer.`);
			}
		} catch (error) {
			console.warn(`Skipping token ID ${tokenId}: ${error.message}`);
		}
	}

	if (validTokenIds.length === 0) {
		console.error("No valid tokens to claim.");
		process.exit(1);
	}

	// Approve migration contract once
	console.log("Setting approval for all tokens on the old contract to the migration contract...");
	let tx = await oldERC721.setApprovalForAll(migrationContractAddress, true);
	await tx.wait();
	console.log("Approval granted.");

	// Attempt to claim all valid tokens
	console.log(`Attempting to claim token IDs [${validTokenIds.join(", ")}]...`);
	try {
		tx = await hyperFrogsV2.batchClaim(validTokenIds, { gasLimit: 4000000 });
		await tx.wait();
		console.log(`Successfully claimed token IDs: ${validTokenIds.join(", ")}`);
	} catch (error) {
		console.error("Error claiming tokens:", error);
	}
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error("Script execution failed:", error);
		process.exit(1);
	});
