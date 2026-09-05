// Deploy the GlobmintVault contract.
//
// Usage:
//   Local:  npx hardhat run scripts/deploy.js            (local in-memory network)
//   Sepolia: npx hardhat run scripts/deploy.js --network sepolia
//
// The deployer account comes from GLOBMINT_DEPLOYER_PRIVATE_KEY (env) — never
// hardcode or commit a private key.
const { ethers, network } = require("hardhat");

// USDC on Sepolia (Circle's canonical deployment). For mainnet, replace with
// 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48.
const USDC_SEPOLIA = "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238";

async function main() {
  const stablecoin = process.env.STABLECOIN_ADDRESS || USDC_SEPOLIA;

  const [deployer] = await ethers.getSigners();
  console.log("Deploying GlobmintVault from:", deployer.address);

  const GlobmintVault = await ethers.getContractFactory("GlobmintVault");
  const vault = await GlobmintVault.deploy(stablecoin);
  await vault.waitForDeployment();

  const address = await vault.getAddress();
  console.log("GlobmintVault deployed to:", address);
  console.log("Stablecoin (USDC):", stablecoin);

  // Write the deployed address to a gitignored local artifacts file.
  const fs = require("fs");
  const out = process.env.DEPLOY_OUT || __dirname + "/../deployments/address.json";
  fs.mkdirSync(require("path").dirname(out), { recursive: true });
  fs.writeFileSync(out, JSON.stringify({ vault: address, stablecoin, network: network.name }, null, 2));
  console.log("Deployed address written to", out);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
