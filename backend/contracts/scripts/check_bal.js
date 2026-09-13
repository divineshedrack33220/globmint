const hre = require("hardhat");
async function main() {
  const usdc = await hre.ethers.getContractAt("MockUSDC", "0x5FbDB2315678afecb367f032d93F642f64180aa3");
  const clone = "0x2FA1d346639EFADa7AcDEad8bFE54f167708F93F";
  const bal = await usdc.balanceOf(clone);
  const vault = await usdc.balanceOf("0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512");
  const signer = await usdc.balanceOf("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");
  console.log("clone USDC:", bal.toString());
  console.log("vault USDC:", vault.toString());
  console.log("signer USDC:", signer.toString());
  console.log("head:", await hre.ethers.provider.getBlockNumber());
  console.log("blocktime of latest:", (await hre.ethers.provider.getBlock("latest")).timestamp);
}
main().catch(e => { console.error(e); process.exit(1); });
