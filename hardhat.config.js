require('@nomicfoundation/hardhat-toolbox');
require('dotenv').config();

const API_URL = process.env.INFURA_RPC;
const PRIVATE_KEY = process.env.SEPOLIA_PRIVATE_KEY;
const API_KEY = process.env.API_KEY;

module.exports = {
	solidity: '0.8.18',
	networks: {
		sepolia: {
			url: API_URL,
			accounts: [PRIVATE_KEY],
		},
	},
	etherscan: {
		apiKey: API_KEY,
	},
};