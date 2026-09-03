-- 0002_ledger.sql
-- Immutable financial ledger with idempotency support.

CREATE TABLE IF NOT EXISTS accounts (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind       TEXT NOT NULL,  -- available | savings | pending | withdrawable
    currency   TEXT NOT NULL DEFAULT 'NGN',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, kind, currency)
);

CREATE TABLE IF NOT EXISTS transactions (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type           TEXT NOT NULL,
    status         TEXT NOT NULL DEFAULT 'created',
    currency       TEXT NOT NULL DEFAULT 'NGN',
    amount_minor   BIGINT NOT NULL DEFAULT 0,
    fee_minor      BIGINT NOT NULL DEFAULT 0,
    exchange_rate  TEXT NOT NULL DEFAULT '',
    reference      TEXT NOT NULL DEFAULT '',
    provider_ref   TEXT NOT NULL DEFAULT '',
    idempotency_key TEXT NOT NULL DEFAULT '',
    metadata       JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_idempotency
    ON transactions(idempotency_key) WHERE idempotency_key <> '';

CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);

CREATE TABLE IF NOT EXISTS ledger_entries (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    account_id     UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    movement       TEXT NOT NULL,  -- credit | debit
    currency       TEXT NOT NULL DEFAULT 'NGN',
    amount_minor   BIGINT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ledger_account ON ledger_entries(account_id, created_at);
CREATE INDEX IF NOT EXISTS idx_ledger_txn ON ledger_entries(transaction_id);

-- Balance cache maintained transactionally alongside ledger writes to keep
-- reads O(1). The authoritative source remains the ledger.
CREATE TABLE IF NOT EXISTS balances (
    account_id  UUID PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
    balance_minor BIGINT NOT NULL DEFAULT 0,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
