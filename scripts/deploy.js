async function main() {
	const contract = await ethers.deployContract('MultiCrowdfunding');
	console.log('Contract address:', await contract.getAddress());
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
