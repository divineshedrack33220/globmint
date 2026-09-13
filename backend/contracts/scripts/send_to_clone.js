// Send MockUSDC from the demo depositor (Account #1) to a given deposit address.
const { ethers } = require("hardhat");

const USDC = process.env.USDC_ADDR || "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const DEST = process.env.DEST;
const AMOUNT = process.env.SEND_AMOUNT || "100"; // USDC (major)

async function main() {
  if (!DEST) throw new Error("DEST address required");
  const signers = await ethers.getSigners();
  const depositor = signers[1]; // Account #1 holds minted USDC from devsetup
  const token = await ethers.getContractAt("MockUSDC", USDC, depositor);
  const bal = await token.balanceOf(depositor.address);
  const amount = ethers.parseUnits(AMOUNT, 6);
  console.log("depositor:", depositor.address, "USDC bal:", ethers.formatUnits(bal, 6));
  if (bal < amount) throw new Error(`insufficient depositor balance (${ethers.formatUnits(bal, 6)})`);
  console.log("sending", AMOUNT, "USDC ->", DEST);
  const tx = await token.transfer(DEST, amount);
  const rc = await tx.wait();
  console.log("SENT. tx:", tx.hash, "block:", rc.blockNumber);
  console.log("dest bal now:", (await token.balanceOf(DEST)).toString());
}

main().catch((e) => { console.error(e); process.exit(1); });