const hre = require("hardhat");
async function main() {
  const signer = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
  const nonce = await hre.ethers.provider.getTransactionCount(signer);
  console.log("current nonce of signer:", nonce);
  console.log("head:", await hre.ethers.provider.getBlockNumber());
  // ripple through the block to see what happened
  const latest = await hre.ethers.provider.getBlock("latest");
  for (let h = 1; h <= latest.number; h++) {
    const b = await hre.ethers.provider.getBlock(h, true);
    for (const tx of b.transactions) {
      console.log(`block ${h} nonce=${tx.nonce} from=${tx.from} to=${tx.to}`);
    }
  }
}
main().catch(e => { console.error(e); process.exit(1); });
