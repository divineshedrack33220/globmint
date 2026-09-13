-- 0018_recovery_addresses.sql — on-chain recovery address for vault clones.
--
-- Phase 3: every per-user clone gains a time-locked recovery path so a user
-- who loses the key to their OWNER wallet is not locked out forever. The
-- clone contract holds the authority (GlobmintVaultClone.recoveryAddress /
-- recoveryDelay / beginRecovery / cancelRecovery / executeRecovery). The
-- backend stores the latest reported recovery state as a CACHE so the API and
-- the indexer can surface it without an on-chain read on every request; the
-- chain remains the source of truth.
--
-- Additive + idempotent: safe to re-run against any prior migration set.

-- Per-user clone recovery address ("" = none set on chain yet).
ALTER TABLE user_vault_clones
    ADD COLUMN IF NOT EXISTS recovery_address TEXT NOT NULL DEFAULT '';

-- Cached owner seat observed on chain (the user's wallet once they take
-- custody, else the platform signer placeholder). Kept in sync by the recovery
-- reconciler so the status surface works without a live node.
ALTER TABLE user_vault_clones
    ADD COLUMN IF NOT EXISTS owner_address TEXT NOT NULL DEFAULT '';

-- Recovery delay in seconds for the user's clone (0 = not armed).
ALTER TABLE user_vault_clones
    ADD COLUMN IF NOT EXISTS recovery_delay BIGINT NOT NULL DEFAULT 0;

-- When the recovery was initiated on chain (0 = not pending). Mirrors the
-- contract's recoveryRequestedAt so the API can show "recoverable at" without
-- a chain call.
ALTER TABLE user_vault_clones
    ADD COLUMN IF NOT EXISTS recovery_requested_at TIMESTAMPTZ;