-- 0015_user_vault_clones.sql
-- Per-user vault clone addresses (EIP-1167 minimal proxies deployed by
-- GlobmintVaultFactory). Gives every account its own on-chain deposit address:
-- anyone can send USDC to it without the recipient ever "connecting" a wallet,
-- the indexer credits the owner of the destination clone, and the address on
-- chain reveals nothing beyond transactions.
CREATE TABLE IF NOT EXISTS user_vault_clones (
    user_id         TEXT PRIMARY KEY,
    clone_address   TEXT NOT NULL UNIQUE,
    factory_address TEXT NOT NULL,
    deploy_tx_hash  TEXT NOT NULL,
    chain_id        BIGINT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);