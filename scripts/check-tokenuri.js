const { ethers } = require("hardhat");

async function main() {
	const tokenId = 8; // Set token ID via env variable
	const contractAddress = "0xC53d409649B7557824c5E6453229d89A6da1a9E0"; // Set contract address via env variable

	if (!tokenId || !contractAddress) {
		console.error("❌ Please provide TOKEN_ID and CONTRACT_ADDRESS.");
		console.error("Example: TOKEN_ID=6 CONTRACT_ADDRESS=0x123... npx hardhat run scripts/getMetadata.js --network mainnet");
		process.exit(1);
	}

	const [signer] = await ethers.getSigners();

	const nftContract = await ethers.getContractAt("IERC721Metadata", contractAddress, signer);

	try {
		const tokenURI = await nftContract.tokenURI(tokenId);
		console.log(`✅ Metadata for token ID ${tokenId}:`);
		console.log(tokenURI);
	} catch (error) {
		console.error(`❌ Error fetching metadata for token ID ${tokenId}:`, error.message);
	}
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error("Script execution failed:", error);
		process.exit(1);
	});
