// Local dev helper: credit per-user vault clone deposit addresses.
//
// The per-user deposit flow keys off the destination address: any USDC sent to
// an account's clone address belongs to that account by construction, so the
// backend indexer credits it with no wallet linking involved.
//
// With privacy mode on (factory deployed with initialPrivacy=true), the clones
// reject raw-address `deposit()` and funds are routed through the commitment
// entry point `depositFor(user, salt, amount)`, which emits
// `DepositedPrivate(commitment, amount)`. The underlying transferFrom still
// emits Transfer(to=clone), so the indexer credits the account either way.
//
//   CLONE_TARGETS="0x0a1... 0x0b2..." SEND_AMOUNT=50 CLONE_USER=0xUser CLONE_SALT=0xSalt... \
//     npx hardhat run scripts/devcreditclones.js --network localhost
//
// Requires CLONE_USER (the account's deposit/linked address) and CLONE_SALT
// (bytes32 hex) when the clone is privacy-enabled; without them it falls back
// to a plain mint + transfer (works for clones whose privacy mode is off).
const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

const AMOUNT = process.env.SEND_AMOUNT || "50"; // USDC (major units, 6 decimals)
const CLONE_USER = process.env.CLONE_USER || "";
const CLONE_SALT = process.env.CLONE_SALT || "";

async function main() {
  const targets = (process.env.CLONE_TARGETS || "")
    .split(",")
    .map((s) => s.trim())
    .filter((a) => a.startsWith("0x"));
  if (targets.length === 0) {
    console.error("usage: CLONE_TARGETS=\"0x... [0x...]\" SEND_AMOUNT=50 npx hardhat run scripts/devcreditclones.js --network localhost");
    process.exit(1);
  }

  const cfg = JSON.parse(fs.readFileSync(
    path.join(__dirname, "..", "deployments", "dev.json"), "utf8"));

  const [signer] = await ethers.getSigners();
  const token = await ethers.getContractAt("MockUSDC", cfg.stablecoin, signer);
  const amount = ethers.parseUnits(AMOUNT, cfg.stablecoin_decimals || 6);

  const useDepositFor = CLONE_USER !== "" && CLONE_SALT !== "";
  if (useDepositFor) {
    if (!/^0x[0-9a-fA-F]{64}$/.test(CLONE_SALT)) {
      console.error("CLONE_SALT must be a 0x-prefixed 64-hex-char bytes32");
      process.exit(1);
    }
    const salt = CLONE_SALT;
    for (const addr of targets) {
      await (await token.mint(signer.address, amount)).wait();
      await (await token.approve(addr, amount)).wait();
      const clone = await ethers.getContractAt("GlobmintVaultClone", addr, signer);
      const tx = await clone.depositFor(CLONE_USER, salt, amount);
      const rc = await tx.wait();
      console.log(`credited (privacy depositFor) ${AMOUNT} USDC -> ${addr} (tx ${tx.hash} block ${rc.blockNumber})`);
    }
  } else {
    for (const addr of targets) {
      await (await token.mint(signer.address, amount)).wait();
      const tx = await token.transfer(addr, amount);
      const rc = await tx.wait();
      console.log(`credited ${AMOUNT} USDC -> ${addr} (tx ${tx.hash} block ${rc.blockNumber})`);
    }
  }
}

main().catch((e) => { console.error(e); process.exitCode = 1; });