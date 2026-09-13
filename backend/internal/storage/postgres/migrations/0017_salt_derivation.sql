-- 0017_salt_derivation.sql — salt provenance: random (legacy) vs user-derived.
--
-- Today every user_salts row is a 16-byte random value minted by the backend on
-- first link (crypto/rand). In the self-custody model the USER is the source of
-- the privacy secret: their wallet signs a stable per-salt agreement and the
-- backend records THAT salt instead of inventing one. Both origins can then be
-- resolved by the indexer, so existing commitments stay live while new ones
-- come from the wallet.
--
-- provenance:
--   'random'         server RNG (legacy rows; kept so old commitments resolve)
--   'wallet-derived' recorded from the user's wallet (source_address set)
--
-- This migration is additive and idempotent (IF NOT EXISTS / NOT NULL DEFAULT),
-- safe to re-run against any prior migration set.

ALTER TABLE user_salts
    ADD COLUMN IF NOT EXISTS derivation TEXT NOT NULL DEFAULT 'random';

-- The wallet address the salt was derived from; NULL/'legacy' for random salts.
-- Empty string means "random": the salt came from the backend RNG.
ALTER TABLE user_salts
    ADD COLUMN IF NOT EXISTS source_address TEXT NOT NULL DEFAULT '';

-- Fingerprint of the signed agreement the wallet produced (hex), so the exact
-- salt is re-derivable client-side and verifiable here. Empty for random salts.
ALTER TABLE user_salts
    ADD COLUMN IF NOT EXISTS signed_message TEXT NOT NULL DEFAULT '';

-- Derivations are a closed set; anything else is a bug, not a salt origin.
ALTER TABLE user_salts
    DROP CONSTRAINT IF EXISTS user_salts_derivation_check;
ALTER TABLE user_salts
    ADD CONSTRAINT user_salts_derivation_check
    CHECK (derivation IN ('random', 'wallet-derived'));

-- Backfill: rows written before this migration are random by construction. The
-- NOT NULL DEFAULT already covers rows created earlier, but keep the empty
-- source_address/signed_message explicit so query shape stays uniform.
UPDATE user_salts
SET derivation = 'random'
WHERE derivation IS NULL OR derivation = '';

-- Mirror provenance onto deposit_addresses.salt rows? No: deposit_addresses.salt
-- is a legacy reference copy of the commitment preimage and its OWNER (the row)
-- is unchanged. The authority remains user_salts, now with provenance.