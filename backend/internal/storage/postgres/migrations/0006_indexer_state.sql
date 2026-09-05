-- 0006_indexer_state.sql
-- Persists the on-chain deposit indexer's last-scanned block so restarts
-- resume from where the previous process left off instead of skipping all
-- historical deposits (which previously left on-chain USDC uncredited).

CREATE TABLE IF NOT EXISTS indexer_state (
    singleton   BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (singleton),
    last_block  BIGINT NOT NULL DEFAULT 0,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed the cursor with block 0 (means: unknown, scan from latest on first run).
INSERT INTO indexer_state (singleton, last_block)
VALUES (TRUE, 0)
ON CONFLICT (singleton) DO NOTHING;
