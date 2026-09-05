-- 0011_indexer_events_and_elevations.sql
-- Adds: (1) a durable replay log for the vault indexer, and (2) the time-lock
-- table backing elevated (high-value) withdrawals that must wait before the
-- signer broadcasts them.

-- Durable event log: one row per confirmed vault transfer the indexer has
-- ingested. Independent of the chain RPC, so replay/audit/tests never need to
-- re-fetch history and idempotency is enforced at ingest time.
CREATE TABLE IF NOT EXISTS indexer_events (
    tx_hash       TEXT   NOT NULL,
    log_index     BIGINT NOT NULL,
    block_number  BIGINT NOT NULL,
    event_type    TEXT   NOT NULL CHECK (event_type IN ('deposited', 'withdrawn')),
    from_addr     TEXT   NOT NULL,
    to_addr       TEXT   NOT NULL,
    value_base    BIGINT NOT NULL,
    ingested_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (tx_hash, log_index)
);
CREATE INDEX IF NOT EXISTS idx_indexer_events_block ON indexer_events (block_number);

-- Time-locked high-value withdrawals. A request above the elevation threshold
-- creates a row in status 'pending' that the sweep loop broadcasts only once
-- release_after passes (then 'broadcasting' -> 'broadcast'). Users can cancel
-- while 'pending'. Every row carries its idempotency key so the ledger debit
-- and the chain send dedupe exactly once.
CREATE TABLE IF NOT EXISTS withdrawal_elevations (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           TEXT NOT NULL,
    destination       TEXT NOT NULL,
    amount_ngn_minor  BIGINT NOT NULL,
    status            TEXT NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'broadcasting', 'broadcast', 'cancelled')),
    requested_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    release_after     TIMESTAMPTZ NOT NULL,
    broadcast_tx_hash TEXT,
    broadcast_at      TIMESTAMPTZ,
    idempotency_key   TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_elevations_due ON withdrawal_elevations (status, release_after);
CREATE INDEX IF NOT EXISTS idx_elevations_user ON withdrawal_elevations (user_id);
-- At most one pending elevation per (user, destination, amount) so retries
-- return the existing row instead of queueing duplicates.
CREATE UNIQUE INDEX IF NOT EXISTS idx_elevations_one_pending
    ON withdrawal_elevations (user_id, destination, amount_ngn_minor)
    WHERE status = 'pending';