-- 0012: withdrawal fee support.
--
-- withdrawal_elevations.fee_minor stores the fee (kobo) computed at request
-- time. It is only debited when the sweeper broadcasts after the time-lock;
-- cancellations never touch it. Instant withdrawals record their fee on
-- transactions.fee_minor (column already exists).
ALTER TABLE withdrawal_elevations
    ADD COLUMN IF NOT EXISTS fee_minor BIGINT NOT NULL DEFAULT 0;

-- Platform fee owner: holds the platform_fees account that collects
-- withdrawal fees. The password hash is unusable and the status keeps it out
-- of every user-facing flow; it exists only to satisfy the ledger FKs.
INSERT INTO users (id, email, password_hash, status)
VALUES ('00000000-0000-0000-0000-000000000001', 'platform-fees@globmint.local', '!', 'system')
ON CONFLICT (id) DO NOTHING;

INSERT INTO accounts (user_id, kind, currency)
VALUES ('00000000-0000-0000-0000-000000000001', 'platform_fees', 'NGN')
ON CONFLICT (user_id, kind, currency) DO NOTHING;
