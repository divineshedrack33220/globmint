// Local dev setup for the custodial on-chain vault flow.
//
// Runs against the local hardhat node (npx hardhat node, http://127.0.0.1:8545):
//   1. Deploys MockUSDC.
//   2. Deploys GlobmintVault bound to MockUSDC (kept for API exposure).
//   3. Deploys GlobmintVaultFactory bound to MockUSDC (per-user clones).
//   4. Mints USDC to the vault/signer (Account #0) so withdrawals can pay out.
//   5. Mints USDC to a "demo depositor" (Account #1) so the deposit indexer
//      has a distinct sender to detect.
//
// Writes machine-consumable configuration to deployments/dev.json (gitignored):
//   {
//     "vault":    "<signer address that holds & moves USDC>",
//     "vault_contract": "<GlobmintVault address>",
//     "clone_factory": "<GlobmintVaultFactory address>",
//     "stablecoin": "<MockUSDC address>",
//     "chain_id":  1337,
//     "rpc_url":  "http://127.0.0.1:8545",
//     "signer_private_key": "<0xac0974...>",   // hardhat Account #0
//     "signer_address": "<0xf39F...>",
//     "depositor_address": "<Account #1>"
//   }
const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

const SIGNER_KEY = process.env.DEV_SIGNER_KEY ||
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

async function main() {
  const signers = await ethers.getSigners();
  const signerWallet = new ethers.Wallet(SIGNER_KEY).connect(ethers.provider);
  const vaultAddress = await signerWallet.getAddress();

  console.log("signer (vault) =", vaultAddress);

  const MockUSDC = await ethers.getContractFactory("MockUSDC");
  const token = await MockUSDC.deploy();
  await token.waitForDeployment();
  const tokenAddress = await token.getAddress();
  console.log("MockUSDC =", tokenAddress);

  const GlobmintVault = await ethers.getContractFactory("GlobmintVault");
  const vc = await GlobmintVault.deploy(tokenAddress);
  await vc.waitForDeployment();
  const contractAddress = await vc.getAddress();
  console.log("GlobmintVault =", contractAddress);

  const GlobmintVaultFactory = await ethers.getContractFactory("GlobmintVaultFactory");
  const factory = await GlobmintVaultFactory.deploy(tokenAddress, true);
  await factory.waitForDeployment();
  const factoryAddress = await factory.getAddress();
  console.log("GlobmintVaultFactory (privacy on) =", factoryAddress);

  // Mint 100,000 USDC to the vault/signer so it can pay out withdrawals.
  const mintVault = await token.mint(vaultAddress, ethers.parseUnits("100000", 6));
  await mintVault.wait();
  console.log("minted 100000 USDC -> vault");

  // Mint 5,000 USDC to a demo depositor (Account #1) to simulate an inbound deposit.
  const depositor = signers[1];
  const mintDepositor = await token.mint(depositor.address, ethers.parseUnits("5000", 6));
  await mintDepositor.wait();
  console.log("minted 5000 USDC -> depositor", depositor.address);

  const out = {
    vault: vaultAddress,
    vault_contract: contractAddress,
    clone_factory: factoryAddress,
    stablecoin: tokenAddress,
    stablecoin_symbol: "USDC",
    stablecoin_name: "USD Coin (Mock)",
    stablecoin_decimals: 6,
    chain_id: 1337,
    network: "hardhat",
    rpc_url: "http://127.0.0.1:8545",
    signer_private_key: SIGNER_KEY,
    signer_address: vaultAddress,
    depositor_address: depositor.address,
    depositor_private_key: (await ethers.provider.getSigner(1)).privateKey,
  };

  const dir = path.join(__dirname, "..", "deployments");
  fs.mkdirSync(dir, { recursive: true });
  const outFile = path.join(dir, "dev.json");
  fs.writeFileSync(outFile, JSON.stringify(out, null, 2));
  console.log("wrote", outFile);
}

main().catch((e) => { console.error(e); process.exitCode = 1; });
