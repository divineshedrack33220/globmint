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
    // Forwarded to a long-running `npx hardhat node` so the Go backend's
    // indexer (GLOBMINT_BLOCKCHAIN_RPC_URL=http://127.0.0.1:8545) sees the
    // same chain as the deploy scripts. Run with:
    //   npx hardhat run scripts/devsetup.js --network localhost
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 1337,
    },
    sepolia: {
      url: process.env.GLOBMINT_BLOCKCHAIN_RPC_URL || "",
      accounts: process.env.GLOBMINT_DEPLOYER_PRIVATE_KEY
        ? [process.env.GLOBMINT_DEPLOYER_PRIVATE_KEY]
        : [],
      chainId: 11155111,
    },
    // ---- L2 global stablecoin groundwork ----
    // USDC settles nearly instantly and cheaply on these rollups; the same
    // GlobmintVault contract deploys untouched. Fund the L2 deployer, set the
    // matching *_NETWORK + *_RPC_URL + *_CONTRACT_ADDRESS in .env, and deploy:
    //   npx hardhat run scripts/deploy.js --network arbitrum
    base: {
      url: process.env.GLOBMINT_BASE_RPC_URL || "",
      accounts: process.env.GLOBMINT_DEPLOYER_PRIVATE_KEY
        ? [process.env.GLOBMINT_DEPLOYER_PRIVATE_KEY]
        : [],
      chainId: 8453,
    },
    "base-sepolia": {
      url: process.env.GLOBMINT_BASE_SEPOLIA_RPC_URL || "",
      accounts: process.env.GLOBMINT_DEPLOYER_PRIVATE_KEY
        ? [process.env.GLOBMINT_DEPLOYER_PRIVATE_KEY]
        : [],
      chainId: 84532,
    },
    arbitrum: {
      url: process.env.GLOBMINT_ARBITRUM_RPC_URL || "",
      accounts: process.env.GLOBMINT_DEPLOYER_PRIVATE_KEY
        ? [process.env.GLOBMINT_DEPLOYER_PRIVATE_KEY]
        : [],
      chainId: 42161,
    },
    "arbitrum-sepolia": {
      url: process.env.GLOBMINT_ARBITRUM_SEPOLIA_RPC_URL || "",
      accounts: process.env.GLOBMINT_DEPLOYER_PRIVATE_KEY
        ? [process.env.GLOBMINT_DEPLOYER_PRIVATE_KEY]
        : [],
      chainId: 421614,
    },
    optimism: {
      url: process.env.GLOBMINT_OPTIMISM_RPC_URL || "",
      accounts: process.env.GLOBMINT_DEPLOYER_PRIVATE_KEY
        ? [process.env.GLOBMINT_DEPLOYER_PRIVATE_KEY]
        : [],
      chainId: 10,
    },
    "optimism-sepolia": {
      url: process.env.GLOBMINT_OPTIMISM_SEPOLIA_RPC_URL || "",
      accounts: process.env.GLOBMINT_DEPLOYER_PRIVATE_KEY
        ? [process.env.GLOBMINT_DEPLOYER_PRIVATE_KEY]
        : [],
      chainId: 11155420,
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
