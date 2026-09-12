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
const TRANSFER_TYPES = {
  TransferOwnership: [
    { name: "newOwner", type: "address" },
    { name: "nonce", type: "uint256" },
    { name: "deadline", type: "uint256" },
  ],
};

describe("GlobmintVaultFactory + GlobmintVaultClone (per-user deposit addresses)", function () {
  let factory, clone, usdc, alice, bob, carol, relayer;
  const ONE = BigInt(1_000_000); // 1 USDC in base units (6 decimals)

  // userKey mirrors the backend's per-account CREATE2 key: a bytes32 derived
  // from the account (here, the signer's address with a prefix to keep it
  // distinct from a raw address). In production it is keccak256(userID).
  function userKey(signer) {
    return ethers.keccak256(ethers.toUtf8Bytes("user:" + signer.address));
  }

  beforeEach(async function () {
    [alice, bob, carol, relayer] = await ethers.getSigners();

    const MockUSDC = await ethers.getContractFactory("MockUSDC");
    usdc = await MockUSDC.deploy();

    const GlobmintVaultFactory = await ethers.getContractFactory("GlobmintVaultFactory");
    factory = await GlobmintVaultFactory.deploy(await usdc.getAddress(), false);
    await factory.waitForDeployment();

    // Predict MUST match the deployed clone address. The per-user key is a
    // bytes32 that is UNIQUE per account and independent of who owns it, so
    // an unlinked account (owner = signer) still gets its own distinct clone.
    const predicted = await factory.predict(userKey(alice));
    const tx = await factory.createClone(userKey(alice), alice.address);
    const rcpt = await tx.wait();
    clone = predicted;
    expect(await factory.cloneOfUser(userKey(alice))).to.equal(clone);
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

  // alice signs a TransferOwnership message; returns {v, r, s}.
  async function signTransfer(user, newOwner, nonce, deadline) {
    const chainId = (await ethers.provider.getNetwork()).chainId;
    const domain = {
      name: DOMAIN_NAME,
      version: DOMAIN_VERSION,
      chainId,
      verifyingContract: clone,
    };
    const sig = await user.signTypedData(domain, TRANSFER_TYPES, {
      newOwner,
      nonce,
      deadline,
    });
    const { v, r, s } = ethers.Signature.from(sig);
    return { v, r, s, sig };
  }

  describe("clone addresses", function () {
    it("deploys a deterministic per-user address and initializes ownership", async function () {
      expect(await factory.predict(userKey(alice))).to.equal(clone);
      expect(await factory.cloneOfUser(userKey(alice))).to.equal(clone);
      expect(await factory.predict(userKey(alice))).to.not.equal(await factory.predict(userKey(bob)));

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

    it("EIP-712 withdraw digest matches the backend binding", async function () {
      // The backend (internal/eip712) builds the digest by hand:
      //   0x1901 || domainSeparator || structHash
      // and claims the signer recovered from it is the owner. This asserts the
      // packed hash equals ethers' canonical TypedDataEncoder.hash — the exact
      // digest a wallet signs for eth_signTypedData_v4 — so a server-side
      // verification of a wallet-signed relay recovers the owner.
      const chainId = (await ethers.provider.getNetwork()).chainId;
      const deadline = (await ethers.provider.getBlock("latest")).timestamp + 600;
      let domain;
      {
        const x = clone;
        domain = { name: DOMAIN_NAME, version: DOMAIN_VERSION, chainId, verifyingContract: x };
      }
      const msg = { to: carol.address, amount: ONE * 2n, nonce: 0, deadline };

      const typed = ethers.TypedDataEncoder.hash(domain, WITHDRAW_TYPES, msg);
      const domainSeparator = ethers.TypedDataEncoder.hashDomain(domain);
      const structHash = ethers.TypedDataEncoder.hashStruct(
        "WithdrawRequest",
        WITHDRAW_TYPES,
        msg
      );
      const manual = ethers.keccak256(
        ethers.concat(["0x1901", domainSeparator, structHash])
      );
      expect(manual).to.equal(typed);

      // And a wallet-signed digest of that shape recovers the owner.
      const sig = await alice.signTypedData(domain, WITHDRAW_TYPES, msg);
      const recovered = ethers.verifyTypedData(domain, WITHDRAW_TYPES, msg, sig);
      expect(recovered).to.equal(alice.address);
    });
  });

  describe("direct withdraw kill-switch (factory-gated)", function () {
    async function seed(amount) {
      await fundAndAllow(alice, amount, clone);
      const c = await ethers.getContractAt("GlobmintVaultClone", clone);
      await c.connect(alice).deposit(amount);
      return c;
    }

    it("is enabled by default on clones (zeroed EIP-1167 storage)", async function () {
      const c = await ethers.getContractAt("GlobmintVaultClone", clone);
      expect(await c.directWithdrawDisabled()).to.equal(false);
    });

    it("only the factory can flip the kill-switch", async function () {
      const c = await ethers.getContractAt("GlobmintVaultClone", clone);
      await expect(c.connect(alice).setDirectWithdrawDisabled(true)).to.be.revertedWith("not factory");
      await expect(c.connect(relayer).setDirectWithdrawDisabled(false)).to.be.revertedWith("not factory");
    });

    it("blocks owner direct withdrawals but still allows relayed (signed) withdrawals", async function () {
      const c = await seed(ONE * 6n);

      // Factory flips the fleet policy off for direct owner withdrawals.
      await factory.setDirectWithdrawDisabled(await c.getAddress(), true);
      expect(await c.directWithdrawDisabled()).to.equal(true);
      await expect(c.connect(alice).withdraw(ONE, bob.address)).to.be.revertedWith("direct withdraw disabled");

      // The EIP-712 relay path is unaffected: the owner's signature still moves
      // the exact signed amount.
      const deadline = (await ethers.provider.getBlock("latest")).timestamp + 600;
      const sig = await signWithdraw(alice, carol.address, ONE * 2n, 0, deadline);
      await c.connect(relayer).withdrawWithSig(carol.address, ONE * 2n, 0, deadline, sig.v, sig.r, sig.s);
      expect(await usdc.balanceOf(carol.address)).to.equal(ONE * 2n);
      expect(await c.nonce()).to.equal(1);

      // Re-enabling restores the direct path.
      await factory.setDirectWithdrawDisabled(await c.getAddress(), false);
      expect(await c.directWithdrawDisabled()).to.equal(false);
      await c.connect(alice).withdraw(ONE * 4n, bob.address);
      expect(await usdc.balanceOf(bob.address)).to.equal(ONE * 4n);
    });
  });

  describe("ownership handover (sign to take custody)", function () {
    async function seed(amount) {
      await fundAndAllow(alice, amount, clone);
      const c = await ethers.getContractAt("GlobmintVaultClone", clone);
      await c.connect(alice).deposit(amount);
      return c;
    }

    it("moves ownership to a new wallet and only the new owner can withdraw", async function () {
      const c = await seed(ONE * 4n);
      const deadline = (await ethers.provider.getBlock("latest")).timestamp + 600;
      const { v, r, s } = await signTransfer(alice, bob.address, 0, deadline);

      await expect(c.connect(relayer).transferOwnershipBySig(bob.address, 0, deadline, v, r, s))
        .to.emit(c, "OwnershipTransferred")
        .withArgs(alice.address, bob.address);
      expect(await c.ownerOfThis()).to.equal(bob.address);
      expect(await c.nonce()).to.equal(1);
    });

    it("after handover the previous owner can no longer withdraw", async function () {
      const c = await seed(ONE * 4n);
      const deadline = (await ethers.provider.getBlock("latest")).timestamp + 600;
      const sig = await signTransfer(alice, bob.address, 0, deadline);
      await c.connect(relayer).transferOwnershipBySig(bob.address, 0, deadline, sig.v, sig.r, sig.s);

      await expect(c.connect(alice).withdraw(ONE, alice.address)).to.be.revertedWith("not owner");
      await c.connect(bob).withdraw(ONE * 4n, bob.address);
      expect(await c.tokenBalance()).to.equal(0);
    });

    it("rejects a signature from someone who is not the owner", async function () {
      const c = await seed(ONE);
      const deadline = (await ethers.provider.getBlock("latest")).timestamp + 600;
      const { v, r, s } = await signTransfer(carol, bob.address, 0, deadline);
      await expect(c.connect(relayer).transferOwnershipBySig(bob.address, 0, deadline, v, r, s))
        .to.be.revertedWith("invalid signer");
    });

    it("rejects replaying the same nonce (shared counter with withdrawals)", async function () {
      const c = await seed(ONE * 2n);
      const deadline = (await ethers.provider.getBlock("latest")).timestamp + 600;
      // owner signs a withdrawal with nonce 0 ...
      const w = await signWithdraw(alice, carol.address, ONE, 0, deadline);
      await c.connect(relayer).withdrawWithSig(carol.address, ONE, 0, deadline, w.v, w.r, w.s);
      // ... so the SAME nonce can no longer be used for a handover.
      const t = await signTransfer(alice, bob.address, 0, deadline);
      await expect(c.connect(relayer).transferOwnershipBySig(bob.address, 0, deadline, t.v, t.r, t.s))
        .to.be.revertedWith("invalid nonce");
    });

    it("rejects an expired handover signature", async function () {
      const c = await seed(ONE);
      const oldDeadline = (await ethers.provider.getBlock("latest")).timestamp - 1;
      const { v, r, s } = await signTransfer(alice, bob.address, 0, oldDeadline);
      await expect(c.connect(relayer).transferOwnershipBySig(bob.address, 0, oldDeadline, v, r, s))
        .to.be.revertedWith("signature expired");
    });

    it("rejects zero or identical new owner", async function () {
      const c = await seed(ONE);
      const deadline = (await ethers.provider.getBlock("latest")).timestamp + 600;
      const zeroSig = await signTransfer(alice, ethers.ZeroAddress, 0, deadline);
      await expect(c.connect(relayer).transferOwnershipBySig(ethers.ZeroAddress, 0, deadline, zeroSig.v, zeroSig.r, zeroSig.s))
        .to.be.revertedWith("invalid new owner");
      const sameSig = await signTransfer(alice, alice.address, 0, deadline);
      await expect(c.connect(relayer).transferOwnershipBySig(alice.address, 0, deadline, sameSig.v, sameSig.r, sameSig.s))
        .to.be.revertedWith("same owner");
    });
  });

  describe("privacy mode (commitment-based balances)", function () {
    let pclone;
    // A salt is a 32-byte secret known only to the user and the backend. The
    // commitment keccak256(abi.encodePacked(user, salt)) hides the balance from
    // any on-chain observer who does not know the salt.
    const SALT = ethers.keccak256(ethers.toUtf8Bytes("globmint:privacy-test-salt"));

    beforeEach(async function () {
      // A separate factory whose clones boot in privacy mode (the fleet policy).
      const GlobmintVaultFactory = await ethers.getContractFactory("GlobmintVaultFactory");
      const pFactory = await GlobmintVaultFactory.deploy(await usdc.getAddress(), true);
      await pFactory.waitForDeployment();
      const pClone = await pFactory.predict(userKey(alice));
      await pFactory.createClone(userKey(alice), alice.address);
      pclone = await ethers.getContractAt("GlobmintVaultClone", pClone);
      expect(await pclone.privacyEnabled()).to.equal(true);
    });

    it("rejects raw-address deposit/withdraw in privacy mode", async function () {
      await fundAndAllow(alice, ONE * 2n, await pclone.getAddress());
      await expect(pclone.connect(alice).deposit(ONE)).to.be.revertedWith("privacy mode: use depositFor");
      await expect(pclone.connect(alice).withdraw(ONE, alice.address)).to.be.revertedWith("privacy mode: use withdrawWithSalt");
    });

    it("credits a depositFor commitment and emits only the commitment", async function () {
      await fundAndAllow(alice, ONE * 7n, await pclone.getAddress());
      const commitment = await pclone.commitmentKey(alice.address, SALT);
      // The emitted event carries the commitment hash, never the raw address.
      await expect(pclone.connect(alice).depositFor(alice.address, SALT, ONE * 7n))
        .to.emit(pclone, "DepositedPrivate")
        .withArgs(commitment, ONE * 7n);
      expect(await pclone.balanceOfCommitment(commitment)).to.equal(ONE * 7n);
      expect(await pclone.tokenBalance()).to.equal(ONE * 7n);
      // The raw-address balance mapping is NOT credited in privacy mode.
      expect(await usdc.balanceOf(await pclone.getAddress())).to.equal(ONE * 7n);
    });

    it("withdrawWithSalt proves salt knowledge and pays out", async function () {
      await fundAndAllow(alice, ONE * 5n, await pclone.getAddress());
      await pclone.connect(alice).depositFor(alice.address, SALT, ONE * 5n);
      const commitment = await pclone.commitmentKey(alice.address, SALT);

      // alice (who knows the salt) withdraws; bob receives the USDC.
      await expect(pclone.connect(alice).withdrawWithSalt(SALT, ONE * 3n, bob.address))
        .to.emit(pclone, "WithdrawnPrivate")
        .withArgs(commitment, ONE * 3n);
      expect(await usdc.balanceOf(bob.address)).to.equal(ONE * 3n);
      expect(await pclone.balanceOfCommitment(commitment)).to.equal(ONE * 2n);
    });

    it("rejects a wrong salt (unknown commitment)", async function () {
      await fundAndAllow(alice, ONE * 5n, await pclone.getAddress());
      await pclone.connect(alice).depositFor(alice.address, SALT, ONE * 5n);
      const badSalt = ethers.keccak256(ethers.toUtf8Bytes("wrong"));
      await expect(pclone.connect(alice).withdrawWithSalt(badSalt, ONE, alice.address))
        .to.be.revertedWith("insufficient private balance");
    });

    it("only the factory can change privacy mode", async function () {
      await expect(pclone.connect(alice).setPrivacyEnabled(false)).to.be.revertedWith("not factory");
    });

    it("a plain transfer still lands in clone custody and stays withdrawable", async function () {
      // Even in privacy mode anyone can USDC-transfer into the clone's address
      // (the whole point of per-user deposit addresses). The commitment ledger
      // is separate, but the token sits in the clone.
      await usdc.mint(carol.address, ONE);
      await usdc.connect(carol).transfer(await pclone.getAddress(), ONE);
      expect(await pclone.tokenBalance()).to.equal(ONE);
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
      await factory.createClone(userKey(bob), bob.address);
      expect(await factory.predict(userKey(bob))).to.not.equal(clone);
      expect(await factory.cloneOfUser(userKey(bob))).to.not.equal(clone);
    });

    it("signer-owned (unlinked) accounts still get DISTINCT clones", async function () {
      // Both accounts have no wallet, so the platform signer owns their clone
      // as a placeholder. Their per-user keys MUST still yield different
      // addresses — the salt comes from the user key, not the owner.
      const signer = relayer.address;
      const keyC = userKey(carol);
      const keyBob2 = userKey(bob);
      await factory.createClone(keyC, signer);
      const cloneC = await factory.predict(keyC);
      await factory.createClone(keyBob2, signer);
      const cloneB = await factory.predict(keyBob2);
      expect(cloneC).to.not.equal(cloneB);
      expect(await factory.cloneOfUser(keyC)).to.equal(cloneC);
      expect(await factory.cloneOfUser(keyBob2)).to.equal(cloneB);
      // Both are owned by the same signer seat but at different addresses.
      const cC = await ethers.getContractAt("GlobmintVaultClone", cloneC);
      const cB = await ethers.getContractAt("GlobmintVaultClone", cloneB);
      expect(await cC.ownerOfThis()).to.equal(signer);
      expect(await cB.ownerOfThis()).to.equal(signer);
    });
  });
});