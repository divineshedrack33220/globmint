const { expect } = require("chai");
const { ethers } = require("hardhat");

// EIP-712 helpers for the clone's withdrawWithSig (relayed withdrawals).
const DOMAIN_NAME = "GlobmintVault";
const DOMAIN_VERSION = "1";
const WITHDRAW_TYPES = {
  WithdrawRequest: [
    { name: "to", type: "address" },
    { name: "amount", type: "uint256" },
    { name: "nonce", type: "uint256" },
    { name: "deadline", type: "uint256" },
  ],
};

describe("GlobmintVaultFactory + GlobmintVaultClone (per-user deposit addresses)", function () {
  let factory, clone, usdc, alice, bob, carol, relayer;
  const ONE = BigInt(1_000_000); // 1 USDC in base units (6 decimals)

  beforeEach(async function () {
    [alice, bob, carol, relayer] = await ethers.getSigners();

    const MockUSDC = await ethers.getContractFactory("MockUSDC");
    usdc = await MockUSDC.deploy();

    const GlobmintVaultFactory = await ethers.getContractFactory("GlobmintVaultFactory");
    factory = await GlobmintVaultFactory.deploy(await usdc.getAddress());
    await factory.waitForDeployment();

    // Predict MUST match the deployed clone address.
    const predicted = await factory.predict(alice.address);
    const tx = await factory.createClone(alice.address);
    const rcpt = await tx.wait();
    clone = predicted;
    expect(await factory.ownerToClone(alice.address)).to.equal(clone);
    expect((await usdc.getAddress()).toLowerCase()).to.equal((await usdc.getAddress()).toLowerCase());
  });

  async function fundAndAllow(user, amount, spender) {
    await usdc.mint(user.address, amount);
    await usdc.connect(user).approve(spender ?? clone, amount);
  }

  // alice signs a WithdrawRequest; returns {v, r, s}.
  async function signWithdraw(user, to, amount, nonce, deadline) {
    const chainId = (await ethers.provider.getNetwork()).chainId;
    const domain = {
      name: DOMAIN_NAME,
      version: DOMAIN_VERSION,
      chainId,
      verifyingContract: clone,
    };
    const sig = await user.signTypedData(domain, WITHDRAW_TYPES, {
      to,
      amount,
      nonce,
      deadline,
    });
    const { v, r, s } = ethers.Signature.from(sig);
    return { v, r, s, sig };
  }

  describe("clone addresses", function () {
    it("deploys a deterministic per-user address and initializes ownership", async function () {
      expect(await factory.predict(alice.address)).to.equal(clone);
      expect(await factory.ownerToClone(alice.address)).to.equal(clone);
      expect(await factory.predict(alice.address)).to.not.equal(await factory.predict(bob.address));

      const code = await ethers.provider.getCode(clone);
      expect(code.length).to.be.greaterThan(2, "clone should have deployed code");

      // Ownership set by the factory; a stranger cannot re-initialize.
      const c = await ethers.getContractAt("GlobmintVaultClone", clone);
      await expect(c.connect(bob).initializer(bob.address)).to.be.revertedWith("not factory");
    });
  });

  describe("receiving funds (no wallet linking)", function () {
    it("credits via deposit()", async function () {
      await fundAndAllow(alice, ONE * 5n, clone);
      const c = await ethers.getContractAt("GlobmintVaultClone", clone);
      await expect(c.connect(alice).deposit(ONE * 5n))
        .to.emit(c, "Deposited")
        .withArgs(alice.address, ONE * 5n);
      expect(await c.tokenBalance()).to.equal(ONE * 5n);
    });

    it("credits via a plain ERC-20 transfer from ANY unlinked wallet", async function () {
      await usdc.mint(carol.address, ONE * 3n); // carol has never "connected" anything
      await usdc.connect(carol).transfer(clone, ONE * 3n);

      const c = await ethers.getContractAt("GlobmintVaultClone", clone);
      expect(await c.tokenBalance()).to.equal(ONE * 3n);
      // Everything in the clone is withdrawable by its owner later.
      expect(await c.ownerOfThis()).to.equal(alice.address);
    });
  });

  describe("withdrawals (sign per withdrawal)", function () {
    async function seed(amount) {
      await fundAndAllow(alice, amount, clone);
      const c = await ethers.getContractAt("GlobmintVaultClone", clone);
      await c.connect(alice).deposit(amount);
      return c;
    }

    it("owner can withdraw directly from their own wallet", async function () {
      const c = await seed(ONE * 6n);
      await c.connect(alice).withdraw(ONE * 6n, bob.address);
      expect(await usdc.balanceOf(bob.address)).to.equal(ONE * 6n);
      expect(await c.tokenBalance()).to.equal(0);
    });

    it("a non-owner cannot withdraw directly", async function () {
      const c = await seed(ONE * 6n);
      await expect(c.connect(bob).withdraw(ONE, bob.address)).to.be.revertedWith("not owner");
    });

    it("relayed withdrawal works with the owner's EIP-712 signature", async function () {
      const c = await seed(ONE * 6n);
      const deadline = (await ethers.provider.getBlock("latest")).timestamp + 600;
      const { v, r, s } = await signWithdraw(alice, carol.address, ONE * 2n, 0, deadline);

      await expect(c.connect(relayer).withdrawWithSig(carol.address, ONE * 2n, 0, deadline, v, r, s))
        .to.emit(c, "Withdrawn")
        .withArgs(carol.address, ONE * 2n);
      expect(await usdc.balanceOf(carol.address)).to.equal(ONE * 2n);
      expect(await c.tokenBalance()).to.equal(ONE * 4n);
      expect(await c.nonce()).to.equal(1);
    });

    it("rejects a signature from the wrong owner", async function () {
      const c = await seed(ONE * 6n);
      const deadline = (await ethers.provider.getBlock("latest")).timestamp + 600;
      const { v, r, s } = await signWithdraw(bob, alice.address, ONE, 0, deadline);
      await expect(c.connect(relayer).withdrawWithSig(alice.address, ONE, 0, deadline, v, r, s))
        .to.be.revertedWith("invalid signer");
    });

    it("rejects replaying the same nonce", async function () {
      const c = await seed(ONE * 6n);
      const deadline = (await ethers.provider.getBlock("latest")).timestamp + 600;
      const sig = await signWithdraw(alice, carol.address, ONE, 0, deadline);
      await c.connect(relayer).withdrawWithSig(carol.address, ONE, 0, deadline, sig.v, sig.r, sig.s);
      await expect(c.connect(relayer).withdrawWithSig(carol.address, ONE, 0, deadline, sig.v, sig.r, sig.s))
        .to.be.revertedWith("invalid nonce");
      // The next nonce IS accepted.
      const sig2 = await signWithdraw(alice, carol.address, ONE, 1, deadline);
      await c.connect(relayer).withdrawWithSig(carol.address, ONE, 1, deadline, sig2.v, sig2.r, sig2.s);
      expect(await c.nonce()).to.equal(2);
    });

    it("rejects an expired deadline", async function () {
      const c = await seed(ONE * 6n);
      const oldDeadline = (await ethers.provider.getBlock("latest")).timestamp - 1;
      const { v, r, s } = await signWithdraw(alice, carol.address, ONE, 0, oldDeadline);
      await expect(c.connect(relayer).withdrawWithSig(carol.address, ONE, 0, oldDeadline, v, r, s))
        .to.be.revertedWith("signature expired");
    });

    it("rejects withdrawing more than the clone holds", async function () {
      const c = await seed(ONE);
      const deadline = (await ethers.provider.getBlock("latest")).timestamp + 600;
      const { v, r, s } = await signWithdraw(alice, carol.address, ONE * 2n, 0, deadline);
      await expect(c.connect(relayer).withdrawWithSig(carol.address, ONE * 2n, 0, deadline, v, r, s))
        .to.be.revertedWith("insufficient balance");
    });
  });

  describe("isolation / hardening", function () {
    it("the bare implementation cannot collect deposits", async function () {
      const GlobmintVaultClone = await ethers.getContractFactory("GlobmintVaultClone");
      const impl = await GlobmintVaultClone.deploy(await usdc.getAddress(), await factory.getAddress());
      await impl.waitForDeployment();
      await fundAndAllow(alice, ONE, await impl.getAddress());
      await expect(impl.connect(alice).deposit(ONE)).to.be.revertedWith("not initialized");
    });

    it("rejects native ETH sent to a clone", async function () {
      await expect(
        alice.sendTransaction({ to: clone, value: ONE })
      ).to.be.revertedWith("ETH not accepted");
    });

    it("two accounts never share a clone", async function () {
      await factory.createClone(bob.address);
      expect(await factory.predict(bob.address)).to.not.equal(clone);
      expect(await factory.ownerToClone(bob.address)).to.not.equal(clone);
    });
  });
});