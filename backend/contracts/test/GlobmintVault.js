const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GlobmintVault", function () {
  let vault;
  let usdc;
  let owner, alice, bob;
  const ONE = BigInt(1_000_000); // 1 USDC in base units (6 decimals)

  beforeEach(async function () {
    [owner, alice, bob] = await ethers.getSigners();

    const MockUSDC = await ethers.getContractFactory("MockUSDC");
    usdc = await MockUSDC.deploy();

    const GlobmintVault = await ethers.getContractFactory("GlobmintVault");
    vault = await GlobmintVault.deploy(await usdc.getAddress());
    await vault.waitForDeployment();
  });

  async function fundAndAllow(user, amount) {
    await usdc.mint(user.address, amount);
    await usdc.connect(user).approve(await vault.getAddress(), amount);
  }

  describe("deposit", function () {
    it("credits the depositor's balance", async function () {
      await fundAndAllow(alice, ONE * 10n);
      await vault.connect(alice).deposit(ONE * 5n);

      expect(await vault.balanceOf(alice.address)).to.equal(ONE * 5n);
      expect(await usdc.balanceOf(await vault.getAddress())).to.equal(ONE * 5n);
    });

    it("rejects a deposit larger than allowance", async function () {
      await usdc.mint(alice.address, ONE * 10n);
      await usdc.connect(alice).approve(await vault.getAddress(), ONE);
      await expect(vault.connect(alice).deposit(ONE * 2n)).to.be.revertedWith(
        "insufficient allowance"
      );
    });

    it("rejects a zero deposit", async function () {
      await fundAndAllow(alice, ONE);
      await expect(vault.connect(alice).deposit(0)).to.be.revertedWith(
        "amount must be > 0"
      );
    });
  });

  describe("depositFor", function () {
    it("credits a different user's balance", async function () {
      // bob pays and approves; alice receives credit
      await usdc.mint(bob.address, ONE * 10n);
      await usdc.connect(bob).approve(await vault.getAddress(), ONE * 10n);
      await vault.connect(bob)["depositFor(address,uint256)"](alice.address, ONE * 3n);

      expect(await vault.balanceOf(alice.address)).to.equal(ONE * 3n);
      expect(await vault.balanceOf(bob.address)).to.equal(0);
    });
  });

  describe("withdraw", function () {
    it("returns USDC to the caller's own address", async function () {
      await fundAndAllow(alice, ONE * 10n);
      await vault.connect(alice).deposit(ONE * 6n);

      const before = await usdc.balanceOf(alice.address);
      await vault.connect(alice).withdraw(ONE * 6n);

      expect(await usdc.balanceOf(alice.address)).to.equal(before + ONE * 6n);
      expect(await vault.balanceOf(alice.address)).to.equal(0);
    });

    it("rejects withdrawing more than the caller's balance", async function () {
      await fundAndAllow(alice, ONE * 2n);
      await vault.connect(alice).deposit(ONE);
      await expect(vault.connect(alice).withdraw(ONE * 2n)).to.be.revertedWith(
        "insufficient balance"
      );
    });
  });

  describe("no-admin / isolation", function () {
    it("has no owner field (no admin concept)", async function () {
      // There is deliberately no owner()/admin() getter. Verify only that the
      // contract does not expose any seize/move function by checking isolation.
      expect(await vault.totalDeposits()).to.equal(0);
    });

    it("a user cannot touch another user's balance", async function () {
      await fundAndAllow(alice, ONE * 5n);
      await vault.connect(alice).deposit(ONE * 5n);

      // bob tries to withdraw — reverts because bob has no balance
      await expect(vault.connect(bob).withdraw(ONE)).to.be.revertedWith(
        "insufficient balance"
      );
      // alice's balance is untouched
      expect(await vault.balanceOf(alice.address)).to.equal(ONE * 5n);
    });
  });

  describe("accounting", function () {
    it("tracks totalDeposits across users", async function () {
      await fundAndAllow(alice, ONE * 10n);
      await fundAndAllow(bob, ONE * 10n);
      await vault.connect(alice).deposit(ONE * 4n);
      await vault.connect(bob).deposit(ONE * 6n);
      expect(await vault.totalDeposits()).to.equal(ONE * 10n);

      await vault.connect(bob).withdraw(ONE * 2n);
      expect(await vault.totalDeposits()).to.equal(ONE * 8n);
    });
  });
});
