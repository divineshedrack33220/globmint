-- Phase 1: EIP-712 signature-gated withdrawals.
--
-- withdrawal_elevations persist the user's pre-signed withdrawWithSig intent
-- so the sweeper can relay the EXACT signed relay (to, amount, nonce,
-- deadline, signature) at release time — the signer/operator never re-signs
-- or mutates a user's authorization.

ALTER TABLE withdrawal_elevations
    ADD COLUMN IF NOT EXISTS signature TEXT,
    ADD COLUMN IF NOT EXISTS deadline BIGINT,
    ADD COLUMN IF NOT EXISTS signed_nonce BIGINT,
    ADD COLUMN IF NOT EXISTS signed_amount_base BIGINT,
    ADD COLUMN IF NOT EXISTS expired_reason TEXT;

-- The sweep marks a stale pre-signed intent "expired" (terminal, not retried);
-- the original status check (0011) predates that state.
ALTER TABLE withdrawal_elevations
    DROP CONSTRAINT IF EXISTS withdrawal_elevations_status_check;
ALTER TABLE withdrawal_elevations
    ADD CONSTRAINT withdrawal_elevations_status_check
    CHECK (status IN ('pending', 'broadcasting', 'broadcast', 'cancelled', 'expired'));