const { ethers } = require("hardhat");

async function main() {
  const signers = await ethers.getSigners();
  const signer = signers[0];
  const tokenAddr = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
  const cloneAddr = "0x2FA1d346639EFADa7AcDEad8bFE54f167708F93F";
  const amount = ethers.parseUnits("100", 6);

  const token = await ethers.getContractAt("MockUSDC", tokenAddr);
  const tx = await token.mint(cloneAddr, amount);
  await tx.wait();
  console.log("Minted 100 USDC to", cloneAddr);
  console.log("TX:", tx.hash);
}

main().catch((e) => { console.error(e); process.exitCode = 1; });
