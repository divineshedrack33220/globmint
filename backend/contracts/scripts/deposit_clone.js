const hre = require("hardhat");
async function main() {
  const usdcAddr = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
  const clone = "0x2FA1d346639EFADa7AcDEad8bFE54f167708F93F";
  const signer = (await hre.ethers.getSigners())[0];
  const usdc = await hre.ethers.getContractAt("MockUSDC", usdcAddr);
  for (const who of ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512", clone, "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"]) {
    console.log("bal", who, (await usdc.balanceOf(who)).toString());
  }
  const signerBal = await usdc.balanceOf(signer.address);
  let from = signer;
  if (signerBal < 100000000n) {
    console.log("signer short on canonical token; minting 10000 USDC to signer");
    await (await usdc.mint(signer.address, hre.ethers.parseUnits("10000", 6))).wait();
  }
  const amount = hre.ethers.parseUnits("100", 6);
  const tx = await usdc.transfer(clone, amount);
  await tx.wait();
  console.log("SENT 100 USDC ->", clone);
  console.log("txhash:", tx.hash, "block:", (await tx.wait()).blockNumber);
  console.log("clone bal now:", (await usdc.balanceOf(clone)).toString());
}
main().catch(e => { console.error(e); process.exit(1); });
