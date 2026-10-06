-- 0023_waitlist_meta.sql
--
-- Additive hardening of the waitlist table, layered on top of 0022 (which is
-- already applied on production, so it must not be edited). Adds attribution
-- metadata for signups collected through the landing page and a normalized
-- unique email key so duplicates are idempotent regardless of case.
--
-- email_lower is a stored generated column: INSERTs always write it from
-- lower(email) so the unique index on it cannot be bypassed by mixed-case
-- input. source/defaults to 'landing' for rows written before this migration.
-- ip_hash is a one-way hash of the client IP (the landing page hashes before
-- sending), never a raw address; user_agent is stored as-is for attribution.
--
-- Idempotent: migrations re-run on every boot.

ALTER TABLE waitlist
    ADD COLUMN IF NOT EXISTS email_lower text GENERATED ALWAYS AS (lower(email)) STORED,
    ADD COLUMN IF NOT EXISTS source     text NOT NULL DEFAULT 'landing',
    ADD COLUMN IF NOT EXISTS ip_hash    text,
    ADD COLUMN IF NOT EXISTS user_agent text,
    ADD COLUMN IF NOT EXISTS confirmed  boolean NOT NULL DEFAULT false;

CREATE UNIQUE INDEX IF NOT EXISTS waitlist_email_lower_key ON waitlist (email_lower);
CREATE INDEX IF NOT EXISTS waitlist_created_at_idx ON waitlist (created_at DESC);