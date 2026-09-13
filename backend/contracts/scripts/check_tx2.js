const hre = require("hardhat");
async function main() {
  const tx = await hre.ethers.provider.getTransaction("0xaf45813044fd479bbd542277b7cb1f3c77999e9f0ea9f7e6f8f4675412b15ffb");
  console.log("transferTxExists:", !!tx, "block:", tx ? tx.blockNumber : "-");
  const tx2 = await hre.ethers.provider.getTransaction("0xd09b585c3a5ebeba8b14f0fe3edf9093411cab005e967db879e5f4dd7add6a59");
  console.log("mintTxExists:", !!tx2, "block:", tx2 ? tx2.blockNumber : "-");
  const usdc = await hre.ethers.getContractAt("MockUSDC", "0x5FbDB2315678afecb367f032d93F642f64180aa3");
  const clone = "0x2FA1d346639EFADa7AcDEad8bFE54f167708F93F";
  console.log("old clone USDC bal (0x5FbD token):", (await usdc.balanceOf(clone)).toString());
  console.log("head:", await hre.ethers.provider.getBlockNumber());
}
main().catch(e => { console.error(e); process.exit(1); });
