-- 0009_pin_hash.sql
-- Transaction PIN hashes for high-value actions (withdrawals etc.).
-- Stored as bcrypt like passwords; never in plaintext.
ALTER TABLE users ADD COLUMN IF NOT EXISTS pin_hash TEXT NOT NULL DEFAULT '';