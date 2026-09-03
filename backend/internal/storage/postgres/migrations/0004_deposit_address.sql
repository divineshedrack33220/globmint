-- 0004_deposit_address.sql
-- Links each user to their own on-chain wallet address for non-custodial
-- deposits into the GlobmintVault contract. The system never holds the user's
-- private key; it only records which address belongs to which user so clients
-- can build approve + deposit calls against the vault.
--
-- user_id and address are each UNIQUE so a user has at most one deposit address
-- and an on-chain address cannot be claimed by more than one user.

CREATE TABLE IF NOT EXISTS deposit_addresses (
    user_id    UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    address    TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_deposit_addresses_addr ON deposit_addresses(address);
