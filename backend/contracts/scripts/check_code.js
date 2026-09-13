const hre = require("hardhat");
async function main() {
  const addrs = ["0x5FbDB2315678afecb367f032d93F642f64180aa3","0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512","0x2FA1d346639EFADa7AcDEad8bFE54f167708F93F"];
  for (const a of addrs) {
    const code = await hre.ethers.provider.getCode(a);
    console.log(a, "codeLen:", code.length);
  }
  const head = await hre.ethers.provider.getBlockNumber();
  console.log("head:", head);
  const b0 = await hre.ethers.provider.getBlock(0);
  const b1 = await hre.ethers.provider.getBlock(1);
  console.log("b0 ts:", b0 ? b0.timestamp : null, "b1 ts:", b1 ? b1.timestamp : null);
}
main().catch(e => { console.error(e); process.exit(1); });
