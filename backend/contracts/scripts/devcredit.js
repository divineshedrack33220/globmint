// Local dev helper: fund every test account linked in `deposit_addresses`.
//
// Each account's deposit address (their "account number") doubles as the
// on-chain SENDER, so the indexer's sender->user lookup credits the right
// account (crediting today is sender-based; see services/vault.go). We mint
// USDC to the linked sender from Account #0 and transfer it to the vault.
//
//   npx hardhat run scripts/devcredit.js --network localhost
//   SEND_AMOUNT=50 npx hardhat run scripts/devcredit.js --network localhost
//
// Deposit addresses currently linked (mirror the dev DB):
//   localplayer 0x70997970C51812dc3A010C7d01b50e0d17dc79C8  (signer #1)
//   test        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC  (signer #2)
//   test2       0x90F79bf6EB2c4f870365E785982E1f101E93b906  (signer #3)
//   testnew     0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65  (signer #4)
//   divineshedrack1 0x9965507D1a55bCC2695C58ba16FB37d819B0a4dc (signer #5)
//   testconfirm 0x976EA74026E726554dB657fA54763abd0C3a0aa9  (signer #6)
const { ethers } = require("hardhat");

const VAULT = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
const MOCKUSDC = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const AMOUNT = process.env.SEND_AMOUNT || "50"; // USDC (major) per account
// Sender signer indexes; override with SENDERS="1,2" to credit one account.
const LINKED_SENDERS = (process.env.SENDERS || "1,2,3,4,5,6")
  .split(",").map((s) => parseInt(s.trim(), 10));

async function main() {
  const signers = await ethers.getSigners();
  const token = await ethers.getContractAt("MockUSDC", MOCKUSDC, signers[0]);
  const amount = ethers.parseUnits(AMOUNT, 6);
  for (const i of LINKED_SENDERS) {
    await (await token.mint(signers[i].address, amount)).wait();
    const tx = await token.connect(signers[i]).transfer(VAULT, amount);
    const rc = await tx.wait();
    console.log(
      `credited ${AMOUNT} USDC via sender ${signers[i].address} (tx ${tx.hash} block ${rc.blockNumber})`
    );
  }
}

main().catch((e) => { console.error(e); process.exitCode = 1; });