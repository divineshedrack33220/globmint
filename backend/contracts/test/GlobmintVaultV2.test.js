const { expect } = require("chai");
const { ethers } = require("hardhat");

// keccak256(abi.encodePacked(user, salt)) — mirrors the contract.
function commitmentOf(user, salt) {
  return ethers.solidityPackedKeccak256(
    ["address", "bytes32"],
    [user, salt]
  );
}

describe("GlobmintVaultV2 (privacy)", function () {
  let vault, usdc;
  let owner, alice, bob;
  const ONE = BigInt(1_000_000); // 1 USDC in base units (6 decimals)

  const SALT = ethers.keccak256(ethers.toUtf8Bytes("alice-random-salt"));

  async function deploy(initialPrivacy) {
    [owner, alice, bob] = await ethers.getSigners();
    const MockUSDC = await ethers.getContractFactory("MockUSDC");
    usdc = await MockUSDC.deploy();
    const GlobmintVaultV2 = await ethers.getContractFactory("GlobmintVaultV2");
    vault = await GlobmintVaultV2.deploy(await usdc.getAddress(), initialPrivacy);
    await vault.waitForDeployment();
  }

  async function fundAndAllow(user, amount) {
    await usdc.mint(user.address, amount);
    await usdc.connect(user).approve(await vault.getAddress(), amount);
  }

  beforeEach(async function () {
    await deploy(true); // privacy mode ON by default for the privacy suite
  });

  it("boots in the requested privacy mode", async function () {
    expect(await vault.privacyEnabled()).to.equal(true);
  });

  it("balanceOf returns 0 for a funded user while privacy mode is on", async function () {
    await fundAndAllow(owner, ONE * 10n);
    await vault.depositFor(alice.address, SALT, ONE * 5n);

    expect(await vault.balanceOf(alice.address)).to.equal(0);
  });

  it("a salt-based deposit credits the commitment balance, not the raw address", async function () {
    await fundAndAllow(owner, ONE * 10n);
    await vault.depositFor(alice.address, SALT, ONE * 5n);

    const c = commitmentOf(alice.address, SALT);
    expect(await vault.balanceOfCommitment(c)).to.equal(ONE * 5n);
    expect(await vault.totalDeposits()).to.equal(ONE * 5n);
    expect(await usdc.balanceOf(await vault.getAddress())).to.equal(ONE * 5n);
  });

  it("a deposit made WITHOUT a salt (raw deposit) reverts in privacy mode", async function () {
    await fundAndAllow(alice, ONE * 10n);
    await expect(vault.connect(alice).deposit(ONE * 5n)).to.be.revertedWith(
      "privacy mode: use depositFor"
    );
    // The stablecoin was never pulled from the depositor.
    expect(await usdc.balanceOf(alice.address)).to.equal(ONE * 10n);
  });

  it("a raw withdrawal reverts in privacy mode; a salt withdrawal succeeds", async function () {
    await fundAndAllow(owner, ONE * 10n);
    await vault.depositFor(alice.address, SALT, ONE * 5n);

    // Raw withdraw() is not allowed while privacy is on.
    await expect(vault.connect(alice).withdraw(ONE * 2n)).to.be.revertedWith(
      "privacy mode: use withdrawWithSalt"
    );

    // withdrawWithSalt with the CORRECT salt pays the caller.
    const before = await usdc.balanceOf(alice.address);
    await vault.connect(alice).withdrawWithSalt(SALT, ONE * 3n);
    expect(await usdc.balanceOf(alice.address)).to.equal(before + ONE * 3n);
    expect(await vault.balanceOfCommitment(commitmentOf(alice.address, SALT))).to.equal(ONE * 2n);
    expect(await vault.totalDeposits()).to.equal(ONE * 2n);
  });

  it("a salt withdrawal with the WRONG salt reverts", async function () {
    await fundAndAllow(owner, ONE * 10n);
    await vault.depositFor(alice.address, SALT, ONE * 5n);

    const wrongSalt = ethers.keccak256(ethers.toUtf8Bytes("not-alice-salt"));
    await expect(
      vault.connect(alice).withdrawWithSalt(wrongSalt, ONE)
    ).to.be.revertedWith("insufficient private balance");

    // Alice's funds are untouched.
    const c = commitmentOf(alice.address, SALT);
    expect(await vault.balanceOfCommitment(c)).to.equal(ONE * 5n);
  });

  it("privacy-mode events expose the commitment but NOT the raw address", async function () {
    await fundAndAllow(owner, ONE * 10n);
    const c = commitmentOf(alice.address, SALT);

    // Deposit emits DepositedPrivate(commitment) — no raw address.
    await expect(
      vault.depositFor(alice.address, SALT, ONE * 4n)
    )
      .to.emit(vault, "DepositedPrivate")
      .withArgs(c, ONE * 4n);

    // Withdrawal emits WithdrawnPrivate(commitment) — no raw address.
    await expect(
      vault.connect(alice).withdrawWithSalt(SALT, ONE * 2n)
    )
      .to.emit(vault, "WithdrawnPrivate")
      .withArgs(c, ONE * 2n);

    const [depEvent] = await vault.queryFilter("DepositedPrivate");
    const [wdEvent] = await vault.queryFilter("WithdrawnPrivate");
    for (const evt of [depEvent, wdEvent]) {
      const topics = [evt.topics[0], evt.topics[1], evt.topics[2], evt.topics[3]];
      // Only topic0 (signature) and topic1 (commitment) are set; the raw user
      // address must not appear anywhere in the topics.
      expect(topics.filter(Boolean).length).to.equal(2);
      expect(evt.topics[1]).to.equal(c);
      expect(evt.topics[2]).to.be.undefined;
      // ...and the address is not in the emitted data either.
      expect(evt.args.user).to.be.undefined;
    }
  });

  it("toggling the mode preserves existing balances", async function () {
    await deploy(false); // start in legacy mode

    // Legacy raw deposit off-mode.
    await fundAndAllow(alice, ONE * 10n);
    await vault.connect(alice).deposit(ONE * 6n);
    expect(await vault.balanceOf(alice.address)).to.equal(ONE * 6n);

    // health check: mode is off; only the guardian can flip it.
    await expect(vault.connect(alice).setPrivacyEnabled(true)).to.be.revertedWith(
      "not the privacy guardian"
    );

    // Flip ON.
    await vault.setPrivacyEnabled(true);
    expect(await vault.privacyEnabled()).to.equal(true);

    // Legacy raw balance is preserved (still readable, still withdrawable via
    // the zero-salt commitment that deposit() seeded).
    expect(await vault.balanceOf(alice.address)).to.equal(ONE * 6n);
    const zeroSaltCommitment = commitmentOf(alice.address, ethers.ZeroHash);
    expect(await vault.balanceOfCommitment(zeroSaltCommitment)).to.equal(ONE * 6n);

    // ... but once privacy is on, the raw-address APIs are disabled.
    await expect(vault.connect(alice).withdraw(ONE * 2n)).to.be.revertedWith(
      "privacy mode: use withdrawWithSalt"
    );

    // Salt withdrawal (zero salt — the one deposit() seeded) succeeds.
    const before = await usdc.balanceOf(alice.address);
    await vault.connect(alice).withdrawWithSalt(ethers.ZeroHash, ONE * 2n);
    expect(await usdc.balanceOf(alice.address)).to.equal(before + ONE * 2n);

    // Flip back OFF: legacy withdraw works again on the remaining raw balance.
    await vault.setPrivacyEnabled(false);
    const before2 = await usdc.balanceOf(alice.address);
    await vault.connect(alice).withdraw(ONE * 4n);
    expect(await usdc.balanceOf(alice.address)).to.equal(before2 + ONE * 4n);
    expect(await vault.totalDeposits()).to.equal(0);
  });

  it("a different user cannot drain a commitment they do not know", async function () {
    await fundAndAllow(owner, ONE * 10n);
    await vault.depositFor(alice.address, SALT, ONE * 5n);
    const c = commitmentOf(alice.address, SALT);

    // Bob cannot withdraw using Alice's commitment — he cannot compute a salt
    // that resolves to Alice; the wrong-salt path reverts on his own commitment.
    await expect(
      vault.connect(bob).withdrawWithSalt(SALT, ONE)
    ).to.be.revertedWith("insufficient private balance");
    expect(await vault.balanceOfCommitment(c)).to.equal(ONE * 5n);
  });
});