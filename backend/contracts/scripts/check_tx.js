const hre = require("hardhat");
async function main() {
  const tx = await hre.ethers.provider.getTransaction("0xaf45813044fd479bbd542277b7cb1f3c77999e9f0ea9f7e6f8f4675412b15ffb");
  console.log("txExists:", !!tx);
  if (tx) {
    console.log("blockNumber:", tx.blockNumber, "from:", tx.from, "to:", tx.to);
    const rc = await hre.ethers.provider.getTransactionReceipt("0xaf45813044fd479bbd542277b7cb1f3c77999e9f0ea9f7e6f8f4675412b15ffb");
    for (const l of rc.logs) {
      console.log("log contract:", l.address, "topic0:", l.topics[0]);
    }
    const head = await hre.ethers.provider.getBlockNumber();
    console.log("current head:", head);
  }
}
main().catch(e => { console.error(e); process.exit(1); });
