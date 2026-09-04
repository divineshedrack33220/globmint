// Send MockUSDC from the demo depositor (Account #1) to the vault address.
// Uses the same MockUSDC + account setup as devsetup.js.
const { ethers } = require("hardhat");

const VAULT = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
const MOCKUSDC = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const AMOUNT = process.env.SEND_AMOUNT || "100"; // USDC (major) to send

async function main() {
  const signers = await ethers.getSigners();
  const depositor = signers[1]; // Account #1 holds minted USDC
  const token = await ethers.getContractAt("MockUSDC", MOCKUSDC, depositor);
  const amount = ethers.parseUnits(AMOUNT, 6);
  console.log("depositor:", depositor.address, "sends", AMOUNT, "USDC ->", VAULT);
  const tx = await token.transfer(VAULT, amount);
  const rc = await tx.wait();
  console.log("sent. tx hash:", tx.hash, "block:", rc.blockNumber);
}

main().catch((e) => { console.error(e); process.exitCode = 1; });
