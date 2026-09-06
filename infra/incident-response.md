# Globmint incident-response runbook

Operator-facing playbook. Amounts in NGN minor (kobo) unless stated.

## On-call truth

- Source of truth for balances is the **ledger**; the chain is the rails.
- Moving money is two hops: `send USDC` then `debit NGN`. A failure between the
  two is the highest-severity incident class (see "Ledger / on-chain mismatch").
- High-value withdrawals are time-locked (elevated): they are only broadcast by
  the elevation sweeper after `release_after`. Users cancel via the API before
  then. **Never broadcast an elevation from the DB manually** — use the sweeper
  or the `usdcsend` tool with the exact same parameters.

## The kill switch

Freeze ALL withdrawals (elevated + instant) without touching keys:

```bash
docker compose exec server sh -c 'echo "GLOBMINT_VAULT_WITHDRAW_ENABLED=false" >> /proc/1/environ'  # does NOT work — see below
```

Real path — edit `.env`:

```bash
GLOBMINT_VAULT_WITHDRAW_ENABLED=false
docker compose up -d --force-recreate server
# verify
curl -s localhost:8081/api/savings/vault-status | jq .withdraw_enabled   # => false
```

Backfills of `GLOBMINT_VAULT_WITHDRAW_ELEVATION_THRESHOLD_MINOR` / delay take
effect the same way (env only, no DB migration).

## 1. Signer wallet low (alert: GlobmintSignerBalanceLow)

- Symptom: `globmint_signer_balance < 10`.
- Refill the signer from the reserves wallet (the vault owner). The slack is
  real funds; on mainnet use a funded, air-gapped signer.
- Elevated withdrawals simply stay pending until funds arrive — no action
  needed on the ledger.

## 2. Indexer lagging (alert: GlobmintIndexerLagHigh)

- Symptoms: deposits slow, `globmint_indexer_lag_blocks` rising.
- Check exactly one leader runs the indexer (advisory lock). Second instances
  must run `-indexer-only` and still lose the lease:
  ```bash
  docker compose ps
  docker compose logs server | grep -i "acquired leadership"
  ```
- If the RPC is degraded, the cursor holds; fix the RPC and the indexer resumes
  (`indexer_state.last_block` is untouched on error).
- Never manually advance `last_block`.

## 3. Elevated withdrawal fails to broadcast

- Symptom: `globmint_outbound_failures_total{reason="elevation"}` rising;
  elevation stuck in `broadcasting` (claimed but failed) or `pending` past due.
- A failed claim is auto-returned to `pending`; the next sweep retries.
- Check: signer key present, vault allowance, RPC. Fix, then let the sweeper
  run — do not double-broadcast by hand.

## 4. Instant withdrawal broadcast failed

- Symptom: `reason="broadcast"` counter rises; user sees an error.
- The withdrawal is **never** (except the bug-class below) debited without a
  broadcast: `send` precedes `debit` and only succeeds together, so a failed
  send debits nothing and the user can retry.

## 5. Ledger / on-chain mismatch (alert: GlobmintLedgerMismatch)

- A USDC transfer left the vault but the NGN debit did not record. **Pause
  withdrawals** (kill switch), then reconcile the signer address vs `globmint`
  ledger.
- Use `cmd/usdcsend` to issue the missing debit-equivalent transfer and
  `cmd/verifychain` to enumerate vault outflows for the window.

## 6. DB rollback / restore

- `docker compose down`, restore `globmint_pgdata` from the last snapshot, then
  `docker compose up -d db`. The indexer re-scans from its persisted cursor.
- Replays are exactly-once guarded by `indexer_events(tx_hash, log_index)` —
  deposits cannot double-credit.

## 7. Key rotation (signer private key)

```bash
export $(grep -E '^GLOBMINT_STABLECOIN_PRIVATE_KEY=' .env)   # last value
# 1. fund a fresh signer. 2. point the app at it:
sed -i 's/GLOBMINT_STABLECOIN_PRIVATE_KEY=.*/GLOBMINT_STABLECOIN_PRIVATE_KEY=<new>/' .env
docker compose up -d --force-recreate server
# 3. verify balance metric reflects the new address; 4. move residue from old signer.
```

Never write keys to compose files, repositories, or logs.

## 8. Key custody (the crown jewel)

The signer key moves **all** vault funds — whoever holds it is the vault. This
applies per environment; test keys (`.wallets/sepolia-testnet.key`, local
hardhat defaults) are worthless and may live on dev machines, but the mainnet
signer (`.wallets/mainnet.key`) must be treated as the business itself:

- **Storage:** `0600` file perms, gitignored (verify with
  `git check-ignore .wallets/mainnet.key`), never in chat/email/tickets/logs.
- **Offline backup:** two encrypted USB copies in separate physical locations.
  Example (do this on an air-gapped machine, never paste real output anywhere):
  `openssl enc -aes-256-cbc -pbkdf2 -in .wallets/mainnet.key -out /mnt/usb1/globmint-mainnet.key.enc`
  then `shred -u` any plaintext transport copies. Test-decrypt once per quarter.
- **Access:** named humans only, least privilege; every use logged (who, when,
  why). No shared copies, no cloud drives, no screenshots.
- **Separation:** deployer key funds deployments only; day-to-day broadcasts
  use the signer. If either is suspected compromised: pause withdrawals (the
  kill switch above), rotate per §7, then reconcile per §5.
- **Drill:** rehearse §7 on Sepolia twice a year so rotation is routine, not
  an incident.

## Escalation

- Platform (indexer, DB, RPC): fix and observe — self-healing by design.
- Treasury (signer, elevation stuck): human decision required. Follow §1/§3.
- Funds-movement mismatch (§5): treat as top priority; reconcile, then run the
  incident-postmortem step.