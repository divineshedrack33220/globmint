require("@nomicfoundation/hardhat-toolbox");

// Load local env (e.g. /home/divine/Desktop/globe mint/.env) without printing.
// Secrets (RPC URL, deployer private key) are read from process.env only and
// must never be hardcoded or committed.
try {
  require("dotenv").config({ path: "../../.env" });
} catch (e) {
  // dotenv optional; environment variables can be provided directly.
}

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: { enabled: true, runs: 200 },
    },
  },
  networks: {
    hardhat: {
      // Local test network. Initialise a funded USDC mock so the vault tests
      // can exercise deposits/withdrawals.
      chainId: 1337,
    },
    sepolia: {
      url: process.env.GLOBMINT_BLOCKCHAIN_RPC_URL || "",
      accounts: process.env.GLOBMINT_DEPLOYER_PRIVATE_KEY
        ? [process.env.GLOBMINT_DEPLOYER_PRIVATE_KEY]
        : [],
      chainId: 11155111,
    },
    mainnet: {
      url: process.env.GLOBMINT_MAINNET_RPC_URL || process.env.GLOBMINT_BLOCKCHAIN_RPC_URL || "",
      accounts: process.env.GLOBMINT_DEPLOYER_PRIVATE_KEY
        ? [process.env.GLOBMINT_DEPLOYER_PRIVATE_KEY]
        : [],
      chainId: 1,
    },
  },
  mocha: {
    timeout: 40000,
  },
};
