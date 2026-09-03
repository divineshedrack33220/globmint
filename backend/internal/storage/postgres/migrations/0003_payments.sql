-- 0003_payments.sql
-- Beneficiaries, saved bank accounts, and exchange-rate book for money flows.

CREATE TABLE IF NOT EXISTS beneficiaries (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name           TEXT NOT NULL,
    bank           TEXT NOT NULL,
    account_number TEXT NOT NULL,
    is_favorite    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, bank, account_number)
);

CREATE INDEX IF NOT EXISTS idx_beneficiaries_user ON beneficiaries(user_id, created_at);

CREATE TABLE IF NOT EXISTS bank_accounts (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    bank_name      TEXT NOT NULL,
    bank_code      TEXT NOT NULL,
    account_number TEXT NOT NULL,
    account_name   TEXT NOT NULL,
    is_default     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, bank_code, account_number)
);

CREATE INDEX IF NOT EXISTS idx_bank_accounts_user ON bank_accounts(user_id, created_at);

CREATE TABLE IF NOT EXISTS exchange_rates (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    base         TEXT NOT NULL,   -- e.g. NGN
    quote        TEXT NOT NULL,   -- e.g. USDT
    rate_minor   BIGINT NOT NULL, -- price in minor units of quote per 1 base major
    fee_bps      INTEGER NOT NULL DEFAULT 0,  -- fee in basis points
    min_minor    BIGINT NOT NULL DEFAULT 0,
    max_minor    BIGINT NOT NULL DEFAULT 0,
    status       TEXT NOT NULL DEFAULT 'active',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (base, quote)
);
