# Globe Mint — Privacy Testing Checklist

*Manual + automated checklist. Run before every mainnet privacy-mode release.
Automated suites: `backend/contracts$ npx hardhat test`,
`backend$ go test ./...`, root `flutter test`.*

## A. Contract (Hardhat)

- [ ] `GlobmintVaultV2` deploys in privacy mode with `balanceOf` returning 0
      for a funded depositor (`test/GlobmintVaultV2.test.js`).
- [ ] `deposit(amount)` and `withdraw(amount)` **revert** in privacy mode with
      the documented privacy strings.
- [ ] `depositFor(user, salt, amount)` credits `balanceOfCommitment(keccak256(user, salt))`
      and **no raw event** leaks the user's address (`DepositedPrivate` only).
- [ ] `withdrawWithSalt(salt, amount)` succeeds only with the exact salt; wrong
      salt → `insufficient private balance`.
- [ ] Toggling privacy on/off preserves existing balances in both mappings
      (no accidental reset).
- [ ] Different user with a different salt cannot drain a commitment (`balance`
      proves possession).
- [ ] Legacy path (`GlobmintVault.sol`) still passes: 3-arg `depositFor`,
      new revert strings, `balanceOfCommitment` assertions.

## B. Backend queries (Go)

- [ ] `go test ./...` green (incl. `services/savings_privacy_integration_test.go`
      and `services/vault_privacy_integration_test.go`).
- [ ] Linking a deposit address in privacy mode generates a **16-byte random
      salt**; re-linking the same user **preserves the original salt**
      (commitment stability).
- [ ] `GET /api/v1/savings/deposit` returns `privacy_enabled: true` and **never
      exposes `salt` or the commitment** in the JSON body.
- [ ] Indexer: a `DepositedPrivate` matching the stored `keccak256(address, salt)`
      credits the right user exactly once.
- [ ] Indexer: a **commitment with no linked salt is ignored** — it is never
      credited to the fallback user.
- [ ] Indexer: legacy `Deposited`/`DepositedRaw` events still credit correctly
      when privacy mode is on (vault `initialPrivacy=false` upgrade path).
- [ ] Crash/replay between blocks: restart mid-range → cursor resumes, no
      double credit (idempotency key `vault-deposit-vault-<tx>:<logidx>`).
- [ ] `migration 0013` re-run is a no-op (idempotent) and never NULLs an
      existing salt.

## C. Backend security review (matches docs/security_privacy.md)

- [ ] All raw-address surfaces in the leak inventory (§2) are documented and
      accepted for launch.
- [ ] Salts are 16 random bytes from `crypto/rand`, never written to logs,
      never returned by any API endpoint.
- [ ] Withdrawal-link residual risk (§2.1) is consciously accepted and a ZK
      note is in the roadmap.

## D. Flutter app

- [ ] `flutter analyze` reports no issues; `flutter test` green.
- [ ] `PrivacyNotice` renders on the **add-money screen** only when
      `privacy_enabled` is true, with the `PrivacyBadge` chip visible.
- [ ] `PrivacyNotice` (compact) renders during **onboarding**
      (`create_account_page.dart`) regardless of server privacy config.
- [ ] When `privacy_enabled` is false: **no badge and no notice** on add-money
      (legacy mode messaging stays).
- [ ] Deposit address shown for "Send USDC" copy still matches the backend
      returned address even while a notice is displayed.

## E. End-to-end smoke (local)

- [ ] Backend `:8081` running with `GLOBMINT_PRIVACY_MODE=true` + migration 0013
      applied.
- [ ] Web build (`flutter build web --no-tree-shake-icons`) served on `:8082`.
- [ ] Register → onboard → link deposit address → `privacy_enabled: true`
      visible → notice + badge appear.
- [ ] Send test USDC to the deposit address → balance shows up on the dashboard
      within one indexer block batch.
- [ ] Empirically verify no `Deposited`-family event with the user's raw address
      is emitted for a privacy-mode deposit (check the explorer tx logs).

## F. Launch gate

- [ ] Vault deployed with `initialPrivacy = true` for a fresh privacy launch.
- [ ] `GLOBMINT_PRIVACY_MODE` set in production config before opening deposits.
- [ ] Fallback usage confirmed limited to legacy `Transfer` events only.
- [ ] README §7 (Security) links this checklist and `docs/security_privacy.md`.